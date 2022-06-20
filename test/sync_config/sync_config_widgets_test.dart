import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/sync/imap_config_mobile.dart';
import 'package:mocktail/mocktail.dart';

import '../widget_test_utils.dart';
import 'sync_config_test_data.dart';
import 'sync_config_test_mocks.dart';

void main() {
  var mock = MockSyncConfigService();
  var mockInboxService = MockSyncInboxService();
  var mockOutboxService = MockOutboxService();

  group('SyncConfig Widgets Tests - ', () {
    setUp(() {
      mockInboxService = MockSyncInboxService();
      mockOutboxService = MockOutboxService();

      when(mockInboxService.init).thenAnswer((_) async {});
      when(mockOutboxService.init).thenAnswer((_) async {});

      getIt
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<SyncInboxService>(mockInboxService);
    });
    tearDown(getIt.reset);

    testWidgets(
        'Widgets shows server information when configured, with connection success',
        (tester) async {
      mock = MockSyncConfigService();
      when(mock.getSharedKey).thenAnswer((_) async => testSharedKey);
      when(mock.getImapConfig).thenAnswer((_) async => testImapConfig);

      when(() => mock.testConnection(testSyncConfigConfigured))
          .thenAnswer((_) async => true);

      getIt.registerSingleton<SyncConfigService>(mock);

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => SyncConfigCubit(
            testOnNetworkChange: true,
          ),
          child: makeTestableWidget(const MobileSyncConfig()),
        ),
      );

      await tester.pumpAndSettle();

      final hostFinder = find.text('Host: ${testImapConfig.host}');
      final portFinder = find.text('Port: ${testImapConfig.port}');
      final folderFinder = find.text('IMAP Folder: ${testImapConfig.folder}');
      final userFinder = find.text('User: ${testImapConfig.userName}');

      expect(hostFinder, findsOneWidget);
      expect(portFinder, findsOneWidget);
      expect(folderFinder, findsOneWidget);
      expect(userFinder, findsOneWidget);

      final successIndicatorFinder =
          find.byContainerColor(color: AppColors.outboxSuccessColor);
      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets('Widgets shows QR scanner when not configured', (tester) async {
      mock = MockSyncConfigService();
      when(mock.getSharedKey).thenAnswer((_) async => null);
      when(mock.getImapConfig).thenAnswer((_) async => null);

      getIt.registerSingleton<SyncConfigService>(mock);

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => SyncConfigCubit(
            testOnNetworkChange: true,
          ),
          child: makeTestableWidget(const MobileSyncConfig()),
        ),
      );

      await tester.pumpAndSettle();
      final scannerLabelFinder = find.text('Scanning Shared Secret...');
      expect(scannerLabelFinder, findsOneWidget);
    });
  });
}
