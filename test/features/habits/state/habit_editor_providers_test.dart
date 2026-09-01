import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habit_editor_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  Future<ProviderContainer> containerWithStoredTypes(
    List<String> stored,
  ) async {
    final journalDb = MockJournalDb();
    when(journalDb.getWorkoutTypes).thenAnswer((_) async => stored);
    await setUpTestGetIt(
      additionalSetup: () => getIt
        ..unregister<JournalDb>()
        ..registerSingleton<JournalDb>(journalDb),
    );
    addTearDown(tearDownTestGetIt);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  // Rows imported in the plugin era say `RUNNING`; older and newer rows say
  // `running`. One activity must appear in the picker once, canonically.
  test(
    'workoutTypesProvider canonicalises, de-duplicates and sorts',
    () async {
      final container = await containerWithStoredTypes([
        'RUNNING',
        'running',
        'BIKING',
        'WALKING_TREADMILL',
      ]);
      expect(await container.read(workoutTypesProvider.future), [
        'cycling',
        'running',
        'walkingTreadmill',
      ]);
    },
  );

  test(
    'workoutTypesProvider drops activities that canonicalise to nothing',
    () async {
      final container = await containerWithStoredTypes(['', '   ']);
      expect(await container.read(workoutTypesProvider.future), isEmpty);
    },
  );

  test(
    'workoutTypesProvider reads the distinct types from the journal',
    () async {
      final journalDb = MockJournalDb();
      when(
        journalDb.getWorkoutTypes,
      ).thenAnswer((_) async => ['running', 'swimming']);
      await setUpTestGetIt(
        additionalSetup: () => getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(journalDb),
      );
      addTearDown(tearDownTestGetIt);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(workoutTypesProvider.future), [
        'running',
        'swimming',
      ]);
    },
  );
}
