import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habit_editor_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
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
