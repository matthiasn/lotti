import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host_services.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

/// Every host question the worker's stack can ask lands on the UI isolate's
/// own store, unchanged, and the answer travels back as is.
void main() {
  late MockSettingsDb settings;
  late MockJournalDb journal;
  late MockVectorClockService vectorClock;
  late List<(String, VectorClock?)> dominanceAsked;
  late DatabaseSyncIsolateHostServices services;

  const clock = VectorClock({'a': 1});

  setUp(() {
    settings = MockSettingsDb();
    journal = MockJournalDb();
    vectorClock = MockVectorClockService();
    dominanceAsked = [];
    services = DatabaseSyncIsolateHostServices(
      settings: settings,
      journal: journal,
      vectorClock: vectorClock,
      localVcDominance: (path, incoming) async {
        dominanceAsked.add((path, incoming));
        return path == 'dominated.json';
      },
    );
  });

  test(
    'settings reads, writes and removals go to the key-value store',
    () async {
      when(() => settings.itemByKey('room')).thenAnswer((_) async => '!r');
      when(
        () => settings.saveSettingsItem('room', '!s'),
      ).thenAnswer((_) async => 1);
      when(() => settings.removeSettingsItem('room')).thenAnswer((_) async {});

      expect(await services.settingsGet('room'), '!r');
      expect(await services.settingsSet('room', '!s'), 1);
      await services.settingsRemove('room');

      verify(() => settings.removeSettingsItem('room')).called(1);
    },
  );

  test(
    'journal lookups include deleted rows and exact conflict versions',
    () async {
      when(
        () => journal.journalEntityMapForIdsIncludingDeleted(['x', 'y']),
      ).thenAnswer((_) async => {'x': testTextEntry});
      when(
        () => journal.openConflictVersion('x', clock),
      ).thenAnswer((_) async => testTextEntry);
      when(() => journal.getConfigFlag('flag')).thenAnswer((_) async => true);

      expect(await services.journalEntities(['x', 'y']), {'x': testTextEntry});
      expect(await services.openConflictVersion('x', clock), testTextEntry);
      expect(await services.configFlag('flag'), isTrue);
    },
  );

  test("the host id is the vector clock service's", () async {
    when(() => vectorClock.getHost()).thenAnswer((_) async => 'host-1');

    expect(await services.vectorClockHost(), 'host-1');
  });

  test(
    'local clock dominance is the injected check, arguments intact',
    () async {
      expect(await services.localVcDominates('dominated.json', clock), isTrue);
      expect(await services.localVcDominates('fresh.json', null), isFalse);

      expect(dominanceAsked, [('dominated.json', clock), ('fresh.json', null)]);
    },
  );
}
