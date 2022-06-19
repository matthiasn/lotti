import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:mocktail/mocktail.dart';

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

    blocTest<SyncConfigCubit, SyncConfigState>(
      'in empty state',
      build: () => SyncConfigCubit(autoLoad: false),
      setUp: () {
        mock = MockSyncConfigService();
        when(mock.getSharedKey).thenAnswer((_) async => null);
        when(mock.getImapConfig).thenAnswer((_) async => null);
        getIt.registerSingleton<SyncConfigService>(mock);
      },
      act: (c) async => c.loadSyncConfig(),
      wait: defaultWait,
      expect: () => <SyncConfigState>[
        SyncConfigState.loading(),
        SyncConfigState.empty(),
      ],
      verify: (c) {
        verify(() => mock.getImapConfig()).called(1);
        verify(() => mock.getSharedKey()).called(1);
      },
    );

  });
}
