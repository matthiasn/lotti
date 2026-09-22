import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/state/recent_searches_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

const _searches = [
  RecentSearch(surface: RecentSearchSurface.habits, query: 'run'),
  RecentSearch(surface: RecentSearchSurface.tasks, query: 'fish feeder'),
];

void main() {
  group('RecentSearchesRepository', () {
    late MockSettingsDb settingsDb;
    late RecentSearchesRepository repository;

    setUp(() {
      settingsDb = MockSettingsDb();
      repository = RecentSearchesRepository(settingsDb);
    });

    test('load decodes the row stored under the Recents key', () async {
      when(
        () => settingsDb.itemByKey(recentSearchesSettingsKey),
      ).thenAnswer((_) async => encodeRecentSearches(_searches));

      expect(await repository.load(), _searches);
    });

    test('load answers an empty list when no row exists', () async {
      when(
        () => settingsDb.itemByKey(recentSearchesSettingsKey),
      ).thenAnswer((_) async => null);

      expect(await repository.load(), isEmpty);
    });

    test('save writes the encoded list under the Recents key', () async {
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      await repository.save(_searches);

      verify(
        () => settingsDb.saveSettingsItem(
          recentSearchesSettingsKey,
          encodeRecentSearches(_searches),
        ),
      ).called(1);
    });
  });

  group('recentSearchesRepositoryProvider', () {
    tearDown(tearDownTestGetIt);

    test('reads through the registered SettingsDb', () async {
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.itemByKey(recentSearchesSettingsKey),
      ).thenAnswer((_) async => encodeRecentSearches(_searches));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final loaded = await container
          .read(recentSearchesRepositoryProvider)
          .load();

      expect(loaded, _searches);
    });
  });
}
