import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/history/state/history_providers.dart';
import 'package:lotti/providers/service_providers.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../history_test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  test('a host without a history database has no history', () {
    final container = ProviderContainer.test();

    expect(container.read(historyDbProvider), isNull);
    expect(container.read(historyAvailableProvider), isFalse);
    expect(container.read(historyRecorderProvider), isNull);
    expect(
      () => container.read(historyServiceProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isA<StateError>(),
        ),
      ),
    );
  });

  test('with a database the recorder runs until the scope goes', () async {
    final bench = HistoryTestBench();
    final fixture = HistoryNavFixture();
    addTearDown(() async {
      await fixture.dispose();
      await bench.close();
    });
    final container = ProviderContainer(
      overrides: [
        historyDbProvider.overrideWithValue(bench.db),
        journalDbProvider.overrideWithValue(bench.journalDb),
        navServiceProvider.overrideWithValue(fixture.nav),
        domainLoggerProvider.overrideWithValue(MockDomainLogger()),
      ],
    );

    expect(container.read(historyAvailableProvider), isTrue);
    expect(container.read(historyRecorderProvider), isNotNull);

    fixture.tasks.beamToNamed('/tasks/t1');
    await pumpEventQueue();
    expect((await bench.db.latestEntry())?.entityId, 't1');

    container.dispose();
    fixture.tasks.beamToNamed('/tasks/t2');
    await pumpEventQueue();
    expect((await bench.db.latestEntry())?.entityId, 't1');
  });
}
