import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../mocks/sync_config_test_mocks.dart';
import '../../../../../widget_test_utils.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);
final _l10n = AppLocalizationsEn();

OutboxItem _item({
  required int id,
  required OutboxStatus status,
  int retries = 0,
}) => OutboxItem(
  id: id,
  createdAt: _epoch,
  updatedAt: _epoch,
  status: status.index,
  retries: retries,
  message: '{"runtimeType":"aiConfigDelete","id":"c$id"}',
  subject: 'subj',
  priority: OutboxPriority.low.index,
);

/// A row whose status index is outside the [OutboxStatus] range, exercising the
/// `null` (unknown status) branches in the page.
OutboxItem _rawItem({required int id, required int statusIndex}) => OutboxItem(
  id: id,
  createdAt: _epoch,
  updatedAt: _epoch,
  status: statusIndex,
  retries: 0,
  message: '{"runtimeType":"aiConfigDelete","id":"c$id"}',
  subject: 'subj',
  priority: OutboxPriority.low.index,
);

MockSyncDatabase _prepareMock({
  List<OutboxItem>? items,
  bool fetchThrows = false,
  bool updateThrows = false,
  List<OutboxDailyVolume> volumeData = const [],
}) {
  final mock = mockSyncDatabaseWithCount(0);
  when(
    () => mock.getDailyOutboxVolume(days: kOutboxVolumeDays),
  ).thenAnswer((_) async => volumeData);
  when(() => mock.updateOutboxItem(any())).thenAnswer(
    (_) async => updateThrows ? throw StateError('write failed') : 1,
  );
  if (fetchThrows) {
    when(
      () => mock.getOutboxItems(limit: any(named: 'limit')),
    ).thenAnswer((_) async => throw StateError('boom'));
  } else if (items != null) {
    when(
      () => mock.getOutboxItems(limit: any(named: 'limit')),
    ).thenAnswer((_) async => items);
  }
  return mock;
}

Future<void> _pump(
  WidgetTester tester, {
  required MockSyncDatabase mock,
  OutboxConnectionState connection = OutboxConnectionState.online,
}) async {
  getIt.registerSingleton<SyncDatabase>(mock);
  await tester.pumpWidget(
    makeTestableWidget(
      const SizedBox(width: 500, height: 1000, child: OutboxMonitorPage()),
      overrides: <Override>[
        syncDatabaseProvider.overrideWithValue(mock),
        outboxConnectionStateProvider.overrideWith(
          (ref) => Stream.value(connection),
        ),
      ],
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(registerAllFallbackValues);

  group('OutboxMonitorPage', () {
    setUp(
      () => setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<UserActivityService>(UserActivityService());
        },
      ),
    );
    tearDown(tearDownTestGetIt);

    testWidgets('an empty queue shows the synced summary and clear state', (
      tester,
    ) async {
      await _pump(tester, mock: _prepareMock(items: const []));
      expect(find.text(_l10n.outboxSummarySynced), findsOneWidget);
      expect(find.text(_l10n.outboxMonitorEmptyTitle), findsOneWidget);
    });

    testWidgets('filters are relabeled and the summary names the failure', (
      tester,
    ) async {
      await _pump(
        tester,
        mock: _prepareMock(
          items: [
            _item(id: 1, status: OutboxStatus.pending),
            _item(id: 2, status: OutboxStatus.error, retries: 2),
            _item(id: 3, status: OutboxStatus.sent),
          ],
        ),
      );
      expect(find.text(_l10n.outboxFilterWaiting), findsOneWidget);
      expect(find.text(_l10n.outboxFilterFailed), findsOneWidget);
      expect(find.text(_l10n.outboxStatusSent), findsWidgets);
      expect(find.text(_l10n.outboxSummaryFailed(1)), findsOneWidget);
    });

    testWidgets('Retry all re-queues every failed item', (tester) async {
      final mock = _prepareMock(
        items: [
          _item(id: 1, status: OutboxStatus.error, retries: 10),
          _item(id: 2, status: OutboxStatus.error, retries: 10),
        ],
      );
      await _pump(tester, mock: mock);

      final retryAll = find.text(_l10n.outboxRetryAll);
      await tester.ensureVisible(retryAll);
      await tester.tap(retryAll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mock.updateOutboxItem(any())).called(2);
    });

    testWidgets('a failed card can be retried with one tap', (tester) async {
      final mock = _prepareMock(
        items: [_item(id: 5, status: OutboxStatus.error, retries: 3)],
      );
      await _pump(tester, mock: mock);

      await tester.tap(find.text(_l10n.outboxFilterFailed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(_l10n.outboxActionRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mock.updateOutboxItem(any())).called(1);
    });

    testWidgets('Remove warns about lost sync, then deletes on confirm', (
      tester,
    ) async {
      final mock = _prepareMock(
        items: [_item(id: 7, status: OutboxStatus.error, retries: 3)],
      );
      when(() => mock.deleteOutboxItemById(7)).thenAnswer((_) async => 1);
      await _pump(tester, mock: mock);

      await tester.tap(find.text(_l10n.outboxFilterFailed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(_l10n.outboxActionRemove));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The safer confirmation spells out the data-loss risk.
      expect(find.text(_l10n.outboxRemoveConfirmMessage), findsOneWidget);

      // The modal confirm is upper-cased, so it doesn't collide with the card.
      await tester.tap(find.text(_l10n.outboxActionRemove.toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mock.deleteOutboxItemById(7)).called(1);
    });

    testWidgets('a fetch failure surfaces an error toast', (tester) async {
      await _pump(tester, mock: _prepareMock(fetchThrows: true));
      expect(find.text(_l10n.outboxMonitorFetchFailed), findsOneWidget);
    });

    testWidgets('sending and unknown-status rows feed the active summary', (
      tester,
    ) async {
      await _pump(
        tester,
        mock: _prepareMock(
          items: [
            _item(id: 1, status: OutboxStatus.sending),
            // Status index out of range -> the page's `null` branch.
            _rawItem(id: 2, statusIndex: 99),
          ],
        ),
      );
      // Sending takes precedence; activeCount counts the single sending row.
      expect(find.text(_l10n.outboxSummarySending(1)), findsOneWidget);
    });

    testWidgets('a retry write failure surfaces the retry-failed toast', (
      tester,
    ) async {
      final mock = _prepareMock(
        items: [_item(id: 5, status: OutboxStatus.error, retries: 3)],
        updateThrows: true,
      );
      await _pump(tester, mock: mock);

      await tester.tap(find.text(_l10n.outboxFilterFailed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(_l10n.outboxActionRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(_l10n.outboxMonitorRetryFailed), findsOneWidget);
    });

    testWidgets('a delete failure surfaces the delete-failed toast', (
      tester,
    ) async {
      final mock = _prepareMock(
        items: [_item(id: 7, status: OutboxStatus.error, retries: 3)],
      );
      when(
        () => mock.deleteOutboxItemById(7),
      ).thenAnswer((_) async => throw StateError('delete failed'));
      await _pump(tester, mock: mock);

      await tester.tap(find.text(_l10n.outboxFilterFailed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(_l10n.outboxActionRemove));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(_l10n.outboxActionRemove.toUpperCase()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(_l10n.outboxMonitorDeleteFailed), findsOneWidget);
    });

    testWidgets('OutboxMonitorBody renders the monitor page', (tester) async {
      final mock = _prepareMock(items: const []);
      getIt.registerSingleton<SyncDatabase>(mock);
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(width: 500, height: 1000, child: OutboxMonitorBody()),
          overrides: <Override>[
            syncDatabaseProvider.overrideWithValue(mock),
            outboxConnectionStateProvider.overrideWith(
              (ref) => Stream.value(OutboxConnectionState.online),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OutboxMonitorPage), findsOneWidget);
      expect(find.text(_l10n.outboxMonitorEmptyTitle), findsOneWidget);
    });
  });
}
