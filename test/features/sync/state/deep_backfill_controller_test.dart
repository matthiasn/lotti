import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
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
