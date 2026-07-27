import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/media/media_repair_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockOutboxService outboxService;
  late MockVectorClockService vectorClockService;
  late MockDomainLogger loggingService;
  late List<SyncMediaRequest> requests;

  const debounce = Duration(seconds: 20);

  MediaRepairService buildService({
    int? maxBatchSize,
    int? maxAttemptsPerEntry,
    int? maxTrackedEntries,
  }) => MediaRepairService(
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
    debounce: debounce,
    maxBatchSize: maxBatchSize,
    maxAttemptsPerEntry: maxAttemptsPerEntry,
    maxTrackedEntries: maxTrackedEntries,
  );

  setUp(() {
    outboxService = MockOutboxService();
    vectorClockService = MockVectorClockService();
    loggingService = MockDomainLogger();
    requests = [];

    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'host-a');
    when(() => outboxService.enqueueMessage(any())).thenAnswer((
      invocation,
    ) async {
      final message = invocation.positionalArguments.first as SyncMessage;
      if (message is SyncMediaRequest) requests.add(message);
    });
    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    when(
      () => loggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  test('coalesces a burst of misses into one request', () {
    fakeAsync((async) {
      final service = buildService();
      addTearDown(service.dispose);

      // A catch-up applying many media entries reports each miss separately.
      for (var i = 0; i < 5; i++) {
        service.reportMissing(entryId: 'entry-$i', relativePath: '/images/$i');
      }
      // Same entry reported twice — e.g. the entry is loaded again before the
      // window closes.
      service.reportMissing(entryId: 'entry-0', relativePath: '/images/0');

      // Nothing goes out while the window is open.
      expect(requests, isEmpty);

      async.elapse(debounce);

      expect(requests, hasLength(1));
      expect(
        requests.single.entryIds,
        ['entry-0', 'entry-1', 'entry-2', 'entry-3', 'entry-4'],
        reason: 'one request per burst, each entry named once',
      );
      expect(requests.single.requesterId, 'host-a');
    });
  });

  test('splits a backlog across successive requests at the batch cap', () {
    fakeAsync((async) {
      final service = buildService(maxBatchSize: 2);
      addTearDown(service.dispose);

      for (var i = 0; i < 5; i++) {
        service.reportMissing(entryId: 'entry-$i', relativePath: '/images/$i');
      }

      async.elapse(debounce);
      expect(requests.single.entryIds, ['entry-0', 'entry-1']);

      // The surplus is not dropped: a fresh window is armed for it.
      async.elapse(debounce);
      expect(requests[1].entryIds, ['entry-2', 'entry-3']);

      async.elapse(debounce);
      expect(requests[2].entryIds, ['entry-4']);

      // Drained — no further traffic.
      async.elapse(debounce * 3);
      expect(requests, hasLength(3));
    });
  });

  test('gives up on an entry after the attempt cap', () {
    fakeAsync((async) {
      final service = buildService(maxAttemptsPerEntry: 2);
      addTearDown(service.dispose);

      // Nobody answers, so the loader keeps reporting the same miss.
      for (var round = 0; round < 5; round++) {
        service.reportMissing(entryId: 'orphan', relativePath: '/images/x');
        async.elapse(debounce);
      }

      expect(
        requests,
        hasLength(2),
        reason: 'a blob no peer holds must not be requested forever',
      );
    });
  });

  test('keeps ids pending when the host id is not resolvable yet', () {
    fakeAsync((async) {
      when(() => vectorClockService.getHost()).thenAnswer((_) async => null);
      final service = buildService();
      addTearDown(service.dispose);

      service.reportMissing(entryId: 'entry-1', relativePath: '/images/1');
      async.elapse(debounce);

      expect(requests, isEmpty);
      expect(
        service.debugPending,
        {'entry-1'},
        reason:
            'an unattributable request is worse than a delayed one; the '
            'entry must survive to be asked for once the host exists',
      );
    });
  });

  test("a failed enqueue does not consume the entry's attempt budget", () {
    fakeAsync((async) {
      when(
        () => outboxService.enqueueMessage(any()),
      ).thenThrow(Exception('outbox unavailable'));

      final service = buildService(maxAttemptsPerEntry: 1);
      addTearDown(service.dispose);

      service.reportMissing(entryId: 'entry-1', relativePath: '/images/1');
      async.elapse(debounce);

      expect(
        service.debugPending,
        {'entry-1'},
        reason:
            'a transient outbox failure is not evidence that no peer has '
            'the blob, so it must not burn the single allowed attempt',
      );

      // With the outbox healthy again the entry is still requestable.
      when(() => outboxService.enqueueMessage(any())).thenAnswer((
        invocation,
      ) async {
        final message = invocation.positionalArguments.first as SyncMessage;
        if (message is SyncMediaRequest) requests.add(message);
      });
      async.elapse(debounce);

      expect(requests.single.entryIds, ['entry-1']);
    });
  });

  test('dispose cancels a pending window so no request escapes', () {
    fakeAsync((async) {
      buildService()
        ..reportMissing(entryId: 'entry-1', relativePath: '/images/1')
        ..dispose();

      async.elapse(debounce * 2);
      expect(requests, isEmpty);
    });
  });

  test('a miss reported after dispose does not re-arm the timer', () {
    fakeAsync((async) {
      buildService()
        ..dispose()
        ..reportMissing(entryId: 'entry-1', relativePath: '/images/1');

      async.elapse(debounce * 2);
      expect(requests, isEmpty);
    });
  });
}
