import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tasks/state/task_list_density_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;
  late ProviderContainer container;

  setUp(() async {
    mocks = await setUpTestGetIt();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  /// Drains the pending microtasks of the controller's async `_load`.
  Future<void> awaitHydration() async {
    for (var i = 0; i < 16; i++) {
      await Future<void>.value();
    }
  }

  group('TaskListDensityController', () {
    test('defaults to expanded (not compact)', () {
      expect(container.read(taskListDensityControllerProvider), isFalse);
    });

    test('hydrates a persisted compact preference', () async {
      when(
        () => mocks.settingsDb.itemByKey(taskListCompactModeSettingsKey),
      ).thenAnswer((_) async => 'true');

      container.read(taskListDensityControllerProvider);
      await awaitHydration();

      expect(container.read(taskListDensityControllerProvider), isTrue);
    });

    test('treats any stored value other than "true" as expanded', () async {
      when(
        () => mocks.settingsDb.itemByKey(taskListCompactModeSettingsKey),
      ).thenAnswer((_) async => 'nope');

      container.read(taskListDensityControllerProvider);
      await awaitHydration();

      expect(container.read(taskListDensityControllerProvider), isFalse);
    });

    test('toggle flips the mode and persists it', () async {
      container.read(taskListDensityControllerProvider.notifier).toggle();
      expect(container.read(taskListDensityControllerProvider), isTrue);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          taskListCompactModeSettingsKey,
          'true',
        ),
      ).called(1);

      container.read(taskListDensityControllerProvider.notifier).toggle();
      expect(container.read(taskListDensityControllerProvider), isFalse);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          taskListCompactModeSettingsKey,
          'false',
        ),
      ).called(1);
    });

    test('a late-arriving load never clobbers a user toggle', () async {
      // The stored value resolves only after the user has already toggled:
      // the load must be discarded, not applied over the fresher edit.
      final storedValue = Completer<String?>();
      when(
        () => mocks.settingsDb.itemByKey(taskListCompactModeSettingsKey),
      ).thenAnswer((_) => storedValue.future);

      container.read(taskListDensityControllerProvider.notifier).toggle();
      expect(container.read(taskListDensityControllerProvider), isTrue);

      storedValue.complete('false');
      await awaitHydration();

      expect(container.read(taskListDensityControllerProvider), isTrue);
    });
  });
}
