import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_list_item.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/sync_config_test_mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  var syncDatabaseMock = MockSyncDatabase();
  final testDateTime = DateTime.fromMillisecondsSinceEpoch(0);

  group('OutboxBadge Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<UserActivityService>(UserActivityService());
    });
    tearDown(getIt.reset);

    testWidgets('OutboxMonitor is rendered', (tester) async {
      const testCount = 999;
      syncDatabaseMock = mockSyncDatabaseWithCount(testCount);

      when(() => syncDatabaseMock.watchOutboxItems(limit: any(named: 'limit')))
          .thenAnswer(
        (_) => Stream<List<OutboxItem>>.fromIterable([
          [
            OutboxItem(
              id: 1,
              createdAt: testDateTime,
              updatedAt: testDateTime,
              status: 1,
              retries: 0,
              message: '{"runtimeType":"aiConfigDelete","id":"config-id"}',
              subject: 'error-subject',
            ),
            OutboxItem(
              id: 2,
              createdAt: testDateTime,
              updatedAt: testDateTime,
              status: 0,
              retries: 1,
              message: '{"runtimeType":"aiConfigDelete","id":"pending"}',
              subject: 'pending-subject',
            ),
            OutboxItem(
              id: 3,
              createdAt: testDateTime,
              updatedAt: testDateTime,
              status: 2,
              retries: 2,
              message: '{"runtimeType":"aiConfigDelete","id":"sent"}',
              subject: 'sent-subject',
            ),
          ]
        ]),
      );

      getIt.registerSingleton<SyncDatabase>(syncDatabaseMock);

      final outboxCubitMock = mockOutboxCubit(OutboxState.online());

      await tester.pumpWidget(
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => outboxCubitMock,
          child: makeTestableWidget(
            const SizedBox(
              width: 500,
              height: 1000,
              child: OutboxMonitorPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pendingControlFinder =
          find.byKey(const ValueKey('syncFilter-pending'));
      expect(pendingControlFinder, findsOneWidget);
      final successControlFinder =
          find.byKey(const ValueKey('syncFilter-success'));
      expect(successControlFinder, findsOneWidget);
      final errorControlFinder = find.byKey(const ValueKey('syncFilter-error'));
      expect(errorControlFinder, findsOneWidget);

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
          .widgetList<OutboxListItem>(
            find.byType(OutboxListItem),
          )
          .toList();
      expect(errorItems, hasLength(1));
      expect(errorItems.first.showRetry, isTrue);
      expect(errorItems.first.showDelete, isTrue);
    });

    testWidgets('delete button shows for error items and triggers confirmation',
        (tester) async {
      syncDatabaseMock = mockSyncDatabaseWithCount(1);

      when(() => syncDatabaseMock.watchOutboxItems(limit: any(named: 'limit')))
          .thenAnswer(
        (_) => Stream<List<OutboxItem>>.fromIterable([
          [
            OutboxItem(
              id: 1,
              createdAt: testDateTime,
              updatedAt: testDateTime,
              status: 2, // error
              retries: 5,
              message: '{"runtimeType":"journalEntity","id":"test-id"}',
              subject: 'error-subject',
            ),
          ]
        ]),
      );

      when(() => syncDatabaseMock.deleteOutboxItemById(1))
          .thenAnswer((_) async => 1);

      getIt.registerSingleton<SyncDatabase>(syncDatabaseMock);

      final outboxCubitMock = mockOutboxCubit(OutboxState.online());

      await tester.pumpWidget(
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => outboxCubitMock,
          child: makeTestableWidget(
            const SizedBox(
              width: 500,
              height: 1000,
              child: OutboxMonitorPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Error tab
      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();

      // Verify delete button is present
      final deleteButtonFinder = find.byKey(const ValueKey('outboxDelete-1'));
      expect(deleteButtonFinder, findsOneWidget);

      // Tap delete button
      await tester.tap(deleteButtonFinder);
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears
      expect(find.textContaining('delete this sync item'), findsOneWidget);
      expect(find.text('DELETE'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders empty state when no outbox items', (tester) async {
      syncDatabaseMock = mockSyncDatabaseWithCount(0);
      when(() => syncDatabaseMock.watchOutboxItems(limit: any(named: 'limit')))
          .thenAnswer(
        (_) => Stream<List<OutboxItem>>.fromIterable([
          <OutboxItem>[],
        ]),
      );

      getIt.registerSingleton<SyncDatabase>(syncDatabaseMock);

      final outboxCubitMock = mockOutboxCubit(OutboxState.online());

      await tester.pumpWidget(
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => outboxCubitMock,
          child: makeTestableWidget(
            const SizedBox(
              width: 500,
              height: 1000,
              child: OutboxMonitorPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Outbox is clear'), findsOneWidget);
      expect(find.textContaining('0 items'), findsOneWidget);
    });

    testWidgets('shows loader before first snapshot then empty state',
        (tester) async {
      syncDatabaseMock = mockSyncDatabaseWithCount(0);
      final controller = StreamController<List<OutboxItem>>();
      when(() => syncDatabaseMock.watchOutboxItems(limit: any(named: 'limit')))
          .thenAnswer((_) => controller.stream);

      getIt.registerSingleton<SyncDatabase>(syncDatabaseMock);

      final outboxCubitMock = mockOutboxCubit(OutboxState.online());

      await tester.pumpWidget(
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => outboxCubitMock,
          child: makeTestableWidget(
            const SizedBox(
              width: 500,
              height: 1000,
              child: OutboxMonitorPage(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.add(<OutboxItem>[]);
      await tester.pumpAndSettle();

      expect(find.text('Outbox is clear'), findsOneWidget);
      await controller.close();
    });
  });
}
