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

import '../../../../mocks/mocks.dart';
import '../../../../mocks/sync_config_test_mocks.dart';
import '../../../../widget_test_utils.dart';

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
  Stream<List<OutboxItem>>? itemStream,
  List<OutboxDailyVolume> volumeData = const [],
}) {
  final mock = mockSyncDatabaseWithCount(count);

  if (volumeData.isNotEmpty) {
    when(() => mock.getDailyOutboxVolume(days: 30))
        .thenAnswer((_) async => volumeData);
  }

  if (itemStream != null) {
    when(() => mock.watchOutboxItems(limit: any(named: 'limit')))
        .thenAnswer((_) => itemStream);
  }

  return mock;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OutboxMonitorPage', () {
    setUp(() {
      getIt.registerSingleton<UserActivityService>(UserActivityService());
    });
    tearDown(getIt.reset);

    testWidgets('renders filter tabs, items, and switches filters',
        (tester) async {
      final mock = _prepareMock(
        count: 999,
        itemStream: Stream<List<OutboxItem>>.fromIterable([
          [
            OutboxItem(
              id: 1,
              createdAt: _epoch,
              updatedAt: _epoch,
              status: 1, // sent
              retries: 0,
              message: '{"runtimeType":"aiConfigDelete","id":"config-id"}',
              subject: 'error-subject',
            ),
            OutboxItem(
              id: 2,
              createdAt: _epoch,
              updatedAt: _epoch,
              status: 0, // pending
              retries: 1,
              message: '{"runtimeType":"aiConfigDelete","id":"pending"}',
              subject: 'pending-subject',
            ),
            OutboxItem(
              id: 3,
              createdAt: _epoch,
              updatedAt: _epoch,
              status: 2, // error
              retries: 2,
              message: '{"runtimeType":"aiConfigDelete","id":"sent"}',
              subject: 'sent-subject',
            ),
          ],
        ]),
      );

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      expect(find.text('Success · 1 item'), findsOneWidget);
      expect(find.byType(OutboxListItem), findsNWidgets(1));

      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();

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
          itemStream: Stream<List<OutboxItem>>.fromIterable([
            [
              OutboxItem(
                id: 1,
                createdAt: _epoch,
                updatedAt: _epoch,
                status: 2,
                retries: 5,
                message: '{"runtimeType":"journalEntity","id":"test-id"}',
                subject: 'error-subject',
              ),
            ],
          ]),
        );

        when(() => mock.deleteOutboxItemById(1)).thenAnswer((_) async => 1);

        await _pumpOutboxMonitorPage(tester, mock: mock);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Error'));
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byKey(const ValueKey('outboxDelete-1'));
        expect(deleteButtonFinder, findsOneWidget);

        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        expect(find.textContaining('delete this sync item'), findsOneWidget);
        expect(find.text('DELETE'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets('renders empty state when no outbox items', (tester) async {
      final mock = _prepareMock(
        itemStream: Stream<List<OutboxItem>>.fromIterable([<OutboxItem>[]]),
      );

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pumpAndSettle();

      expect(find.text('Outbox is clear'), findsOneWidget);
      expect(find.textContaining('0 items'), findsOneWidget);
    });

    testWidgets('shows loader before first snapshot then empty state',
        (tester) async {
      final controller = StreamController<List<OutboxItem>>();
      final mock = _prepareMock(itemStream: controller.stream);

      await _pumpOutboxMonitorPage(tester, mock: mock);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.add(<OutboxItem>[]);
      await tester.pumpAndSettle();

      expect(find.text('Outbox is clear'), findsOneWidget);
      await controller.close();
    });

    group('OutboxVolumeChart integration', () {
      testWidgets(
        'renders bar chart when volume data exists',
        (tester) async {
          final mock = _prepareMock(
            itemStream: Stream<List<OutboxItem>>.fromIterable([<OutboxItem>[]]),
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
          await tester.pumpAndSettle();

          expect(find.byType(OutboxVolumeChart), findsOneWidget);
          expect(find.byType(TimeSeriesBarChart), findsOneWidget);
          expect(find.text('Daily sync volume'), findsOneWidget);
        },
      );

      testWidgets(
        'hides bar chart when no volume data exists',
        (tester) async {
          final mock = _prepareMock(
            itemStream: Stream<List<OutboxItem>>.fromIterable([<OutboxItem>[]]),
          );

          await _pumpOutboxMonitorPage(tester, mock: mock);
          await tester.pumpAndSettle();

          expect(find.byType(TimeSeriesBarChart), findsNothing);
          expect(find.text('Daily sync volume'), findsNothing);
        },
      );

      testWidgets(
        'shows error state when provider fails',
        (tester) async {
          final mock = _prepareMock(
            itemStream: Stream<List<OutboxItem>>.fromIterable([<OutboxItem>[]]),
          );

          await _pumpOutboxMonitorPage(
            tester,
            mock: mock,
            extraOverrides: [
              outboxDailyVolumeProvider.overrideWith(
                (ref) async => throw Exception('Volume query failed'),
              ),
            ],
          );
          await tester.pumpAndSettle();

          expect(find.byType(TimeSeriesBarChart), findsNothing);
          expect(find.textContaining('Volume query failed'), findsOneWidget);
        },
      );

      testWidgets(
        'chart coexists with outbox items list',
        (tester) async {
          final mock = _prepareMock(
            count: 1,
            itemStream: Stream<List<OutboxItem>>.fromIterable([
              [
                OutboxItem(
                  id: 1,
                  createdAt: _epoch,
                  updatedAt: _epoch,
                  status: 0,
                  retries: 0,
                  message: '{"runtimeType":"aiConfigDelete","id":"test"}',
                  subject: 'test-subject',
                ),
              ],
            ]),
            volumeData: [
              OutboxDailyVolume(
                date: DateTime(2024, 3, 15),
                totalBytes: 5120,
                itemCount: 3,
              ),
            ],
          );

          await _pumpOutboxMonitorPage(tester, mock: mock);
          await tester.pumpAndSettle();

          expect(find.byType(TimeSeriesBarChart), findsOneWidget);
          expect(find.text('Daily sync volume'), findsOneWidget);
          expect(find.byType(OutboxListItem), findsOneWidget);
        },
      );
    });
  });
}
