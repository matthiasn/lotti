import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_monitor.dart';
import 'package:lotti/features/settings/ui/widgets/outbox/outbox_list_item.dart';
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

      when(() => syncDatabaseMock.watchOutboxItems()).thenAnswer(
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
    });
  });
}
