import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_service.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  // The poller listens to the app lifecycle.
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockDeepBackfillService service;
  late ProviderContainer container;

  void Function(DeepBackfillProgress)? onProgressOf(Invocation invocation) =>
      invocation.namedArguments[#onProgress]
          as void Function(DeepBackfillProgress)?;

  setUp(() async {
    service = MockDeepBackfillService();
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<DeepBackfillService>(service),
    );
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  test("reports the round's progress while it runs, then how many records "
      'it listed', () async {
    final release = Completer<void>();
    when(
      () => service.runRound(onProgress: any(named: 'onProgress')),
    ).thenAnswer((invocation) async {
      onProgressOf(invocation)?.call(
        const DeepBackfillProgress(
          payloadType: SyncSequencePayloadType.journalEntity,
          batches: 1,
          records: 2,
          total: 5,
        ),
      );
      await release.future;
      return const DeepBackfillRoundSummary(
        roundId: 'round-1',
        batches: 3,
        recordsByType: {
          SyncSequencePayloadType.journalEntity: 4,
          SyncSequencePayloadType.entryLink: 1,
        },
      );
    });

    final run = container
        .read(deepBackfillControllerProvider.notifier)
        .runRound();
    await Future<void>.value();

    final running = container.read(deepBackfillControllerProvider);
    expect(running.isRunning, isTrue);
    expect((running.advertised, running.total), (2, 5));

    release.complete();
    await run;

    final done = container.read(deepBackfillControllerProvider);
    expect(done.isRunning, isFalse);
    expect(done.isDone, isTrue);
    expect(done.advertised, 5);
    expect(done.progress, 1);
    expect(done.error, isNull);
  });

  test('ignores a second start while a round is running', () async {
    final release = Completer<void>();
    when(
      () => service.runRound(onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async {
      await release.future;
      return const DeepBackfillRoundSummary(
        roundId: 'round-1',
        batches: 1,
        recordsByType: {},
      );
    });
    final notifier = container.read(deepBackfillControllerProvider.notifier);

    final first = notifier.runRound();
    await notifier.runRound();
    release.complete();
    await first;

    verify(
      () => service.runRound(onProgress: any(named: 'onProgress')),
    ).called(1);
  });

  group('deepBackfillRecordCountsProvider', () {
    const journal = SyncSequencePayloadType.journalEntity;
    const agents = SyncSequencePayloadType.agentEntity;
    late StreamController<SyncSequencePayloadType> changes;
    late List<Set<SyncSequencePayloadType>?> counted;

    /// Stubs a service holding [journal] and [agents] rows that grow by one
    /// with every count of their type; [fail] decides which counts throw.
    void stubCounts({
      bool Function(Set<SyncSequencePayloadType>? only)? fail,
    }) {
      var journalRows = 100;
      var agentRows = 200;
      when(
        () => service.recordCounts(only: any(named: 'only')),
      ).thenAnswer((invocation) async {
        final only =
            invocation.namedArguments[#only] as Set<SyncSequencePayloadType>?;
        counted.add(only);
        if (fail?.call(only) ?? false) throw StateError('database busy');
        return {
          if (only == null || only.contains(journal)) journal: ++journalRows,
          if (only == null || only.contains(agents)) agents: ++agentRows,
        };
      });
    }

    setUp(() {
      changes = StreamController<SyncSequencePayloadType>.broadcast();
      counted = [];
      when(() => service.recordChanges).thenAnswer((_) => changes.stream);
    });

    tearDown(() => changes.close());

    test('reads the counts from the deep backfill service', () async {
      stubCounts();

      // An auto-dispose provider needs a listener to outlive its first read.
      container.listen(deepBackfillRecordCountsProvider, (_, _) {});

      expect(await container.read(deepBackfillRecordCountsProvider.future), {
        journal: 101,
        agents: 201,
      });
    });

    test('counts nothing again while no table changes, until the full '
        'recount interval has passed', () {
      fakeAsync((async) {
        stubCounts();
        final seen = <Map<SyncSequencePayloadType, int>?>[];
        container.listen(
          deepBackfillRecordCountsProvider,
          (_, next) => seen.add(next.value),
        );
        async.flushMicrotasks();
        expect(counted, [null]);

        async
          ..elapse(
            SyncTuning.recordCountsFullRecountInterval -
                SyncTuning.recordCountsRefreshInterval,
          )
          ..flushMicrotasks();
        expect(counted, [null], reason: 'an idle page costs no counts');

        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(
          counted,
          [null, null],
          reason:
              'the backstop for writes the '
              'database does not report',
        );
        expect(seen.last, {journal: 102, agents: 202});
      });
    });

    test('re-counts only the types whose table changed, on the next tick, '
        'over the last counts', () {
      fakeAsync((async) {
        stubCounts();
        final seen = <Map<SyncSequencePayloadType, int>?>[];
        container.listen(
          deepBackfillRecordCountsProvider,
          (_, next) => seen.add(next.value),
        );
        async.flushMicrotasks();

        changes
          ..add(agents)
          ..add(agents);
        async.flushMicrotasks();
        expect(counted, [null], reason: 'changes wait for the tick');

        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(counted, [
          null,
          {agents},
        ]);
        expect(seen.last, {journal: 101, agents: 202});

        async
          ..elapse(SyncTuning.recordCountsRefreshInterval * 3)
          ..flushMicrotasks();
        expect(counted, hasLength(2), reason: 'a change is counted once');
      });
    });

    test('a change that lands while its type is being counted is counted '
        'again on the next tick', () {
      fakeAsync((async) {
        final release = Completer<void>();
        var calls = 0;
        when(
          () => service.recordCounts(only: any(named: 'only')),
        ).thenAnswer((invocation) async {
          calls++;
          if (calls == 2) await release.future;
          return {agents: calls};
        });
        container.listen(deepBackfillRecordCountsProvider, (_, _) {});
        async.flushMicrotasks();

        changes.add(agents);
        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(calls, 2);

        changes.add(agents);
        release.complete();
        async
          ..flushMicrotasks()
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(calls, 3);
      });
    });

    test('a failed count surfaces as an error and is retried on the next '
        'tick, a full one in full and a changed type alone', () {
      fakeAsync((async) {
        var failNext = true;
        stubCounts(
          fail: (_) {
            final fail = failNext;
            failNext = false;
            return fail;
          },
        );
        final seen = <AsyncValue<Map<SyncSequencePayloadType, int>?>>[];
        container.listen(
          deepBackfillRecordCountsProvider,
          (_, next) => seen.add(next),
        );
        async.flushMicrotasks();
        expect(seen.last.hasError, isTrue);

        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(counted, [null, null]);
        expect(seen.last.value, {journal: 101, agents: 201});

        failNext = true;
        changes.add(journal);
        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(seen.last.hasError, isTrue);

        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(counted.skip(2), [
          {journal},
          {journal},
        ]);
        expect(seen.last.value, {journal: 102, agents: 201});
      });
    });

    test('stops counting and listening for changes once nothing listens', () {
      fakeAsync((async) {
        stubCounts();
        final subscription = container.listen(
          deepBackfillRecordCountsProvider,
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(changes.hasListener, isTrue);

        subscription.close();
        async
          ..flushMicrotasks()
          ..elapse(SyncTuning.recordCountsFullRecountInterval * 2)
          ..flushMicrotasks();
        expect(counted, [null]);
        expect(changes.hasListener, isFalse);
      });
    });

    test('stops counting while its listener is paused — a desktop tab '
        'switched away from keeps the page mounted offstage — and counts in '
        'full at once when it resumes', () {
      fakeAsync((async) {
        stubCounts();
        final subscription = container.listen(
          deepBackfillRecordCountsProvider,
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(counted, [null]);

        subscription.pause();
        changes.add(agents);
        async
          ..elapse(SyncTuning.recordCountsFullRecountInterval * 4)
          ..flushMicrotasks();
        expect(counted, [null], reason: 'nothing counted for an unseen page');

        subscription.resume();
        async.flushMicrotasks();
        expect(counted, [null, null]);
        changes.add(journal);
        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(counted.last, {journal}, reason: 'and follows changes again');
      });
    });

    test('a hidden app stays quiet when the page resumes behind it', () {
      final binding = TestWidgetsFlutterBinding.instance
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      fakeAsync((async) {
        stubCounts();
        final subscription = container.listen(
          deepBackfillRecordCountsProvider,
          (_, _) {},
        );
        async.flushMicrotasks();

        subscription.pause();
        binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        subscription.resume();
        async
          ..elapse(SyncTuning.recordCountsFullRecountInterval * 2)
          ..flushMicrotasks();
        expect(counted, [null]);
      });
    });

    test('stops counting while the app is hidden, and counts in full at '
        'once when it shows again', () {
      final binding = TestWidgetsFlutterBinding.instance
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      fakeAsync((async) {
        stubCounts();
        final subscription = container.listen(
          deepBackfillRecordCountsProvider,
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(counted, [null]);

        binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        changes.add(agents);
        async
          ..elapse(SyncTuning.recordCountsFullRecountInterval * 2)
          ..flushMicrotasks();
        // A route kept on the stack keeps the provider alive in the
        // background; it must not keep counting there.
        expect(counted, [null]);

        binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(
          counted,
          [null, null],
          reason:
              'counts at once on return, the '
              'change made while hidden included',
        );
        changes.add(journal);
        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(counted.last, {journal}, reason: 'and follows changes again');

        subscription.close();
        async.flushMicrotasks();
      });
    });

    test('is null where no sync stack runs', () async {
      await setUpTestGetIt();
      container.listen(deepBackfillRecordCountsProvider, (_, _) {});

      expect(
        await container.read(deepBackfillRecordCountsProvider.future),
        isNull,
      );
    });
  });

  test('records the error that stops a round', () async {
    when(
      () => service.runRound(onProgress: any(named: 'onProgress')),
    ).thenThrow(StateError('no host'));

    await container.read(deepBackfillControllerProvider.notifier).runRound();

    final state = container.read(deepBackfillControllerProvider);
    expect(state.isRunning, isFalse);
    expect(state.isDone, isFalse);
    expect(state.error, contains('no host'));
  });
}
