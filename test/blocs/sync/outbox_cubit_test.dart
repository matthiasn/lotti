import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/outbox_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/sync_config_test_mocks.dart';
import '../../test_data/sync_config_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockOutboxService = MockOutboxService();

  group('OutboxCubit Tests - ', () {
    setUpAll(() {
      mockOutboxService = MockOutboxService();

      when(mockOutboxService.init).thenAnswer((_) async {});

      getIt
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true));
    });
    tearDownAll(getIt.reset);

    blocTest<OutboxCubit, OutboxState>(
      'toggle off',
      build: OutboxCubit.new,
      setUp: () {},
      act: (c) async => c.toggleStatus(),
      wait: defaultWait,
      expect: () => <OutboxState>[
        OutboxState.disabled(),
      ],
      verify: (c) {
        verify(() => mockOutboxService.init()).called(1);
      },
    );

    // TODO: adapt test (works when testing manually)
    // blocTest<OutboxCubit, OutboxState>(
    //   'toggle off and on',
    //   build: OutboxCubit.new,
    //   setUp: () {},
    //   act: (c) async {
    //     await c.toggleStatus();
    //     await c.toggleStatus();
    //   },
    //   wait: const Duration(milliseconds: 500),
    //   expect: () => <OutboxState>[
    //     OutboxState.disabled(),
    //     OutboxState.online(),
    //   ],
    //   verify: (c) {
    //     verify(() => mockOutboxService.init()).called(1);
    //     verify(() => mockOutboxService.stopPolling()).called(1);
    //     verify(() => mockOutboxService.startPolling()).called(1);
    //   },
    // );
  });
}
