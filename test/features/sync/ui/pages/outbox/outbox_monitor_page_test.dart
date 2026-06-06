import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_list_item.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_volume_chart.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../mocks/sync_config_test_mocks.dart';
import '../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Shared test helpers
// ---------------------------------------------------------------------------

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

/// Pumps an [OutboxMonitorPage] with the given mock inside the standard
/// test harness.
Future<void> _pumpOutboxMonitorPage(
  WidgetTester tester, {
  required MockSyncDatabase mock,
  List<Override> extraOverrides = const [],
}) async {
  getIt.registerSingleton<SyncDatabase>(mock);

  await tester.pumpWidget(
    makeTestableWidget(
      const SizedBox(
        width: 500,
        height: 1000,
        child: OutboxMonitorPage(),
      ),
      overrides: [
        syncDatabaseProvider.overrideWithValue(mock),
        ...extraOverrides,
      ],
    ),
  );
}

MockSyncDatabase _prepareMock({
  int count = 0,
  List<OutboxItem>? items,
  Future<List<OutboxItem>>? itemsFuture,
  List<OutboxDailyVolume> volumeData = const [],
}) {
  final mock = mockSyncDatabaseWithCount(count);

  when(
    () => mock.getDailyOutboxVolume(days: kOutboxVolumeDays),
  ).thenAnswer((_) async => volumeData);

  if (itemsFuture != null) {
    when(
      () => mock.getOutboxItems(limit: any(named: 'limit')),
    ).thenAnswer((_) => itemsFuture);
  } else if (items != null) {
    when(
      () => mock.getOutboxItems(limit: any(named: 'limit')),
    ).thenAnswer((_) async => items);
  }

  return mock;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

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

    testWidgets('renders filter tabs, items, and switches filters', (
      tester,
    ) async {
      final mock = _prepareMock(
        count: 999,
        items: [
          OutboxItem(
            id: 1,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 1, // sent
            retries: 0,
            message: '{"runtimeType":"aiConfigDelete","id":"config-id"}',
            subject: 'error-subject',
            priority: OutboxPriority.low.index,
          ),
          OutboxItem(
            id: 2,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 0, // pending
            retries: 1,
            message: '{"runtimeType":"aiConfigDelete","id":"pending"}',
            subject: 'pending-subject',
            priority: OutboxPriority.low.index,
          ),
          OutboxItem(
            id: 3,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 2, // error
            retries: 2,
            message: '{"runtimeType":"aiConfigDelete","id":"sent"}',
            subject: 'sent-subject',
            priority: OutboxPriority.low.index,
          ),
        ],
      );

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('syncFilter-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('syncFilter-success')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('syncFilter-error')),
        findsOneWidget,
      );

      expect(find.text('Pending · 1 item'), findsOneWidget);
      expect(find.text('Retries: 1 Retry'), findsOneWidget);
      expect(find.byType(OutboxListItem), findsNWidgets(1));

      await tester.tap(find.text('Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Success · 1 item'), findsOneWidget);
      expect(find.byType(OutboxListItem), findsNWidgets(1));

      await tester.tap(find.text('Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final errorItems = tester
          .widgetList<OutboxListItem>(find.byType(OutboxListItem))
          .toList();
      expect(errorItems, hasLength(1));
      expect(errorItems.first.showRetry, isTrue);
      expect(errorItems.first.showDelete, isTrue);
    });

    testWidgets(
      'delete button shows for error items and triggers confirmation',
      (tester) async {
        final mock = _prepareMock(
          count: 1,
          items: [
            OutboxItem(
              id: 1,
              createdAt: _epoch,
              updatedAt: _epoch,
              status: 2,
              retries: 5,
              message: '{"runtimeType":"journalEntity","id":"test-id"}',
              subject: 'error-subject',
              priority: OutboxPriority.low.index,
            ),
          ],
        );

        when(() => mock.deleteOutboxItemById(1)).thenAnswer((_) async => 1);

        await _pumpOutboxMonitorPage(tester, mock: mock);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Error'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final deleteButtonFinder = find.byKey(const ValueKey('outboxDelete-1'));
        expect(deleteButtonFinder, findsOneWidget);

        await tester.tap(deleteButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('delete this sync item'), findsOneWidget);
        expect(find.text('DELETE'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets('confirming delete shows a success toast', (tester) async {
      final mock = _prepareMock(
        count: 1,
        items: [
          OutboxItem(
            id: 42,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 2,
            retries: 5,
            message: '{"runtimeType":"journalEntity","id":"test-id"}',
            subject: 'error-subject',
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      when(() => mock.deleteOutboxItemById(42)).thenAnswer((_) async => 1);

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('outboxDelete-42')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mock.deleteOutboxItemById(42)).called(1);
      expect(find.text('Item deleted'), findsOneWidget);
    });

    testWidgets('delete failure shows an error toast', (tester) async {
      final mock = _prepareMock(
        count: 1,
        items: [
          OutboxItem(
            id: 43,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 2,
            retries: 5,
            message: '{"runtimeType":"journalEntity","id":"test-id"}',
            subject: 'error-subject',
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      when(
        () => mock.deleteOutboxItemById(43),
      ).thenThrow(Exception('DB offline'));

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('outboxDelete-43')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Delete failed'), findsOneWidget);
    });

    testWidgets('confirming retry shows a success toast', (tester) async {
      final mock = _prepareMock(
        count: 1,
        items: [
          OutboxItem(
            id: 77,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 2,
            retries: 5,
            message: '{"runtimeType":"journalEntity","id":"test-id"}',
            subject: 'error-subject',
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      when(() => mock.updateOutboxItem(any())).thenAnswer((_) async => 1);

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('outboxRetry-77')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('RETRY NOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mock.updateOutboxItem(any())).called(1);
      expect(find.text('Retry scheduled'), findsOneWidget);
    });

    testWidgets('retry failure shows an error toast', (tester) async {
      final mock = _prepareMock(
        count: 1,
        items: [
          OutboxItem(
            id: 78,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 2,
            retries: 5,
            message: '{"runtimeType":"journalEntity","id":"test-id"}',
            subject: 'error-subject',
            priority: OutboxPriority.low.index,
          ),
        ],
      );
      when(
        () => mock.updateOutboxItem(any()),
      ).thenThrow(Exception('DB offline'));

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('outboxRetry-78')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('RETRY NOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Retry failed'), findsOneWidget);
    });

    testWidgets('renders empty state when no outbox items', (tester) async {
      final mock = _prepareMock(items: const <OutboxItem>[]);

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Outbox is clear'), findsOneWidget);
      expect(find.textContaining('0 items'), findsOneWidget);
    });

    testWidgets('shows loader before first fetch resolves then empty state', (
      tester,
    ) async {
      final completer = Completer<List<OutboxItem>>();
      final mock = _prepareMock(itemsFuture: completer.future);

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const <OutboxItem>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Outbox is clear'), findsOneWidget);
    });

    testWidgets('surfaces a toast when the initial fetch fails', (
      tester,
    ) async {
      final mock = mockSyncDatabaseWithCount(0);
      when(
        () => mock.getDailyOutboxVolume(days: kOutboxVolumeDays),
      ).thenAnswer((_) async => const <OutboxDailyVolume>[]);
      when(
        () => mock.getOutboxItems(limit: any(named: 'limit')),
      ).thenThrow(Exception('DB offline'));

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining("Couldn't load the outbox"), findsOneWidget);
      // Page must drop out of the loading state so pull-to-refresh is
      // reachable; without this the spinner would hang forever.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'mounts a RefreshIndicator wired to the outbox fetch',
      (tester) async {
        var fetchCount = 0;
        final mock = mockSyncDatabaseWithCount(0);
        when(
          () => mock.getDailyOutboxVolume(days: kOutboxVolumeDays),
        ).thenAnswer((_) async => const <OutboxDailyVolume>[]);
        when(
          () => mock.getOutboxItems(limit: any(named: 'limit')),
        ).thenAnswer((_) async {
          fetchCount += 1;
          return const <OutboxItem>[];
        });

        await _pumpOutboxMonitorPage(tester, mock: mock);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(fetchCount, 1);

        // The page must mount a RefreshIndicator so users can pull to
        // re-query without a live `watch()` stream. The post-mutation
        // refetch tests below exercise the same `_fetch` path.
        final indicator = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        await indicator.onRefresh();
        expect(fetchCount, 2);
      },
    );

    testWidgets('confirming delete refetches the outbox', (tester) async {
      var fetchCount = 0;
      final mock = mockSyncDatabaseWithCount(1);
      when(
        () => mock.getDailyOutboxVolume(days: kOutboxVolumeDays),
      ).thenAnswer((_) async => const <OutboxDailyVolume>[]);
      when(
        () => mock.getOutboxItems(limit: any(named: 'limit')),
      ).thenAnswer((_) async {
        fetchCount += 1;
        return [
          OutboxItem(
            id: 99,
            createdAt: _epoch,
            updatedAt: _epoch,
            status: 2,
            retries: 5,
            message: '{"runtimeType":"journalEntity","id":"test-id"}',
            subject: 'error-subject',
            priority: OutboxPriority.low.index,
          ),
        ];
      });
      when(() => mock.deleteOutboxItemById(99)).thenAnswer((_) async => 1);

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fetchCount, 1);

      await tester.tap(find.text('Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('outboxDelete-99')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => mock.deleteOutboxItemById(99)).called(1);
      // Initial init() fetch + post-delete refresh.
      expect(fetchCount, 2);
    });

    group('OutboxVolumeChart integration', () {
      testWidgets(
        'renders bar chart when volume data exists',
        (tester) async {
          final mock = _prepareMock(
            items: const <OutboxItem>[],
            volumeData: [
              OutboxDailyVolume(
                date: DateTime(2024, 3, 10),
                totalBytes: 10240,
                itemCount: 5,
              ),
              OutboxDailyVolume(
                date: DateTime(2024, 3, 11),
                totalBytes: 20480,
                itemCount: 8,
              ),
            ],
          );

          await _pumpOutboxMonitorPage(tester, mock: mock);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(OutboxVolumeChart), findsOneWidget);
          expect(find.byType(TimeSeriesBarChart), findsOneWidget);
          expect(find.text('Daily sync volume'), findsOneWidget);
        },
      );

      testWidgets(
        'hides bar chart when no volume data exists',
        (tester) async {
          final mock = _prepareMock(items: const <OutboxItem>[]);

          await _pumpOutboxMonitorPage(tester, mock: mock);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(TimeSeriesBarChart), findsNothing);
          expect(find.text('Daily sync volume'), findsNothing);
        },
      );

      testWidgets(
        'shows error state when provider fails',
        (tester) async {
          final mock = _prepareMock(items: const <OutboxItem>[]);

          await _pumpOutboxMonitorPage(
            tester,
            mock: mock,
            extraOverrides: [
              outboxDailyVolumeProvider.overrideWith(
                (ref) async => throw Exception('Volume query failed'),
              ),
            ],
          );
          // Suppress RenderFlex overflow errors during settle
          final originalOnError = FlutterError.onError;
          final overflowErrors = <FlutterErrorDetails>[];
          FlutterError.onError = (details) {
            if (details.toString().contains('overflowed')) {
              overflowErrors.add(details);
              return;
            }
            originalOnError?.call(details);
          };

          await tester.pumpAndSettle();

          FlutterError.onError = originalOnError;

          expect(find.byType(TimeSeriesBarChart), findsNothing);
          // The raw exception message should not be displayed
          expect(find.textContaining('Volume query failed'), findsNothing);
          // Generic error text is shown via a dedicated key
          expect(
            find.byKey(const ValueKey('outboxVolumeChart-error')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'chart coexists with outbox items list',
        (tester) async {
          final mock = _prepareMock(
            count: 1,
            items: [
              OutboxItem(
                id: 1,
                createdAt: _epoch,
                updatedAt: _epoch,
                status: 0,
                retries: 0,
                message: '{"runtimeType":"aiConfigDelete","id":"test"}',
                subject: 'test-subject',
                priority: OutboxPriority.low.index,
              ),
            ],
            volumeData: [
              OutboxDailyVolume(
                date: DateTime(2024, 3, 15),
                totalBytes: 5120,
                itemCount: 3,
              ),
            ],
          );

          await _pumpOutboxMonitorPage(tester, mock: mock);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(TimeSeriesBarChart), findsOneWidget);
          expect(find.text('Daily sync volume'), findsOneWidget);
          expect(find.byType(OutboxListItem), findsOneWidget);
        },
      );
    });
  });
}
