import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  test("loginStateStreamProvider relays the service's plain login states, "
      'without touching the SDK client', () async {
    final service = MockMatrixService();
    final states = StreamController<SyncLoginState>.broadcast();
    addTearDown(states.close);
    when(() => service.loginStateChanges).thenAnswer((_) => states.stream);
    final container = ProviderContainer(
      overrides: [matrixServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final seen = <SyncLoginState>[];
    container.listen<AsyncValue<SyncLoginState>>(
      loginStateStreamProvider,
      (_, next) => next.whenData(seen.add),
    );
    states
      ..add(SyncLoginState.loggedIn)
      ..add(SyncLoginState.loggedOut);
    await pumpEventQueue();

    expect(seen, [SyncLoginState.loggedIn, SyncLoginState.loggedOut]);
    verifyNever(() => service.client);
  });
}
