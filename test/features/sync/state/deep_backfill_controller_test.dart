import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
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
    test('reads the counts from the deep backfill service', () async {
      when(service.recordCounts).thenAnswer(
        (_) async => {SyncSequencePayloadType.journalEntity: 276711},
      );

      // An auto-dispose provider needs a listener to outlive its first read.
      container.listen(deepBackfillRecordCountsProvider, (_, _) {});

      expect(await container.read(deepBackfillRecordCountsProvider.future), {
        SyncSequencePayloadType.journalEntity: 276711,
      });
    });

    test('re-counts every interval while listened, keeps polling past a '
        'failed count, and stops once nothing listens', () {
      fakeAsync((async) {
        var calls = 0;
        when(service.recordCounts).thenAnswer((_) async {
          calls++;
          if (calls == 2) throw StateError('database busy');
          return {SyncSequencePayloadType.journalEntity: calls};
        });
        final seen = <AsyncValue<Map<SyncSequencePayloadType, int>?>>[];
        final subscription = container.listen(
          deepBackfillRecordCountsProvider,
          (_, next) => seen.add(next),
        );

        async.flushMicrotasks();
        expect(calls, 1);
        expect(seen.last.value, {SyncSequencePayloadType.journalEntity: 1});

        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(calls, 2);
        expect(seen.last.hasError, isTrue);

        async
          ..elapse(SyncTuning.recordCountsRefreshInterval)
          ..flushMicrotasks();
        expect(calls, 3);
        expect(seen.last.value, {SyncSequencePayloadType.journalEntity: 3});

        subscription.close();
        async
          ..flushMicrotasks()
          ..elapse(SyncTuning.recordCountsRefreshInterval * 5)
          ..flushMicrotasks();
        expect(calls, 3);
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
