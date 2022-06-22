import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/outbox/outbox_monitor.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';
import '../sync_config_test_mocks.dart';

void main() {
  var syncDatabaseMock = MockSyncDatabase();

  group('OutboxBadge Widget Tests - ', () {
    setUp(() {});
    tearDown(getIt.reset);

    testWidgets('OutboxMonitor is rendered', (tester) async {
      const testCount = 999;
      syncDatabaseMock = mockSyncDatabaseWithCount(testCount);

      when(
        () => syncDatabaseMock.watchOutboxItems(
          limit: any(named: 'limit'),
          statuses: any(named: 'statuses'),
        ),
      ).thenAnswer(
        (_) => Stream<List<OutboxItem>>.fromIterable([
          [
            OutboxItem(
              id: 1,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
              status: 1,
              retries: 0,
              message: 'message',
              subject: 'subject',
            ),
            OutboxItem(
              id: 2,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
              status: 0,
              retries: 1,
              message: 'message',
              subject: 'subject',
            ),
            OutboxItem(
              id: 2,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
              status: 2,
              retries: 2,
              message: 'message',
              subject: 'subject',
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
              child: OutboxMonitorPage(leadingIcon: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pendingControlFinder = find.text('pending');
      expect(pendingControlFinder, findsOneWidget);
      final allControlFinder = find.text('all');
      expect(allControlFinder, findsOneWidget);
      final errorControlFinder = find.text('error');
      expect(errorControlFinder, findsOneWidget);

      await tester.tap(allControlFinder);
      await tester.tap(errorControlFinder);

      expect(find.text('0 retries - no attachment'), findsOneWidget);
      expect(find.text('1 retry - no attachment'), findsOneWidget);
      expect(find.text('2 retries - no attachment'), findsOneWidget);
    });
  });
}
