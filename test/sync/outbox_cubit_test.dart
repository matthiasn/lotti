import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:mocktail/mocktail.dart';

import 'sync_config_test_data.dart';
import 'sync_config_test_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockOutboxService = MockOutboxService();

  group('OutboxCubit Tests - ', () {
    setUp(() {
      mockOutboxService = MockOutboxService();

      when(mockOutboxService.init).thenAnswer((_) async {});
      when(mockOutboxService.startPolling).thenAnswer((_) async {});
      when(mockOutboxService.stopPolling).thenAnswer((_) async {});

      getIt.registerSingleton<OutboxService>(mockOutboxService);
    });
    tearDown(getIt.reset);

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
        verify(() => mockOutboxService.stopPolling()).called(1);
      },
    );

    blocTest<OutboxCubit, OutboxState>(
      'toggle off and on',
      build: OutboxCubit.new,
      setUp: () {},
      act: (c) async {
        await c.toggleStatus();
        await c.toggleStatus();
      },
      wait: defaultWait,
      expect: () => <OutboxState>[
        OutboxState.disabled(),
        OutboxState.online(),
      ],
      verify: (c) {
        verify(() => mockOutboxService.init()).called(1);
        verify(() => mockOutboxService.stopPolling()).called(1);
        verify(() => mockOutboxService.startPolling()).called(1);
      },
    );
  });
}
