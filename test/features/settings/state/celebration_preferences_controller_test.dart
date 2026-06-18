import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    final mocks = await setUpTestGetIt();
    // Writes succeed; reads default to "never set" (null) unless a test stubs
    // a specific key, so the controller starts all-enabled.
    when(
      () => mocks.settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  group('CelebrationPreferences', () {
    test('allEnabled has every switch on', () {
      const prefs = CelebrationPreferences.allEnabled();
      expect(prefs.habits, isTrue);
      expect(prefs.checklistItems, isTrue);
      expect(prefs.tasks, isTrue);
    });

    test('copyWith replaces only the named field, with value equality', () {
      const base = CelebrationPreferences.allEnabled();
      final tasksOff = base.copyWith(tasks: false);

      expect(tasksOff.tasks, isFalse);
      expect(tasksOff.habits, isTrue);
      expect(tasksOff.checklistItems, isTrue);
      expect(tasksOff, isNot(base));
      // Two independently-built equal values compare equal and hash equally.
      expect(tasksOff, base.copyWith(tasks: false));
      expect(tasksOff.hashCode, base.copyWith(tasks: false).hashCode);
    });
  });

  group('build', () {
    test('defaults to all enabled before hydration', () {
      expect(
        container.read(celebrationPreferencesControllerProvider),
        const CelebrationPreferences.allEnabled(),
      );
    });

    test(
      'hydrates a persisted "false" into only the matching switch',
      () async {
        container.dispose();
        await tearDownTestGetIt();
        final mocks = await setUpTestGetIt();
        when(
          () => mocks.settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mocks.settingsDb.itemByKey('CELEBRATE_CHECKLIST_ITEMS'),
        ).thenAnswer((_) async => 'false');
        container = ProviderContainer();

        final completer = Completer<CelebrationPreferences>();
        container
          ..listen(celebrationPreferencesControllerProvider, (_, next) {
            if (!completer.isCompleted && !next.checklistItems) {
              completer.complete(next);
            }
          })
          ..read(celebrationPreferencesControllerProvider);

        final result = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        expect(result.checklistItems, isFalse);
        expect(result.habits, isTrue);
        expect(result.tasks, isTrue);
      },
    );
  });

  group('setters', () {
    test('setTasks(false) updates state and persists "false"', () async {
      await container
          .read(celebrationPreferencesControllerProvider.notifier)
          .setTasks(enabled: false);

      expect(
        container.read(celebrationPreferencesControllerProvider).tasks,
        isFalse,
      );
      verify(
        () => getIt<SettingsDb>().saveSettingsItem('CELEBRATE_TASKS', 'false'),
      ).called(1);
    });

    test('switches persist independently and leave the others on', () async {
      final notifier = container.read(
        celebrationPreferencesControllerProvider.notifier,
      );
      await notifier.setHabits(enabled: false);
      await notifier.setChecklistItems(enabled: false);

      final prefs = container.read(celebrationPreferencesControllerProvider);
      expect(prefs.habits, isFalse);
      expect(prefs.checklistItems, isFalse);
      expect(prefs.tasks, isTrue);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem('CELEBRATE_HABITS', 'false'),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          'CELEBRATE_CHECKLIST_ITEMS',
          'false',
        ),
      ).called(1);
    });

    test('celebrationPreferences reflects the controller value', () async {
      await container
          .read(celebrationPreferencesControllerProvider.notifier)
          .setHabits(enabled: false);

      expect(container.read(celebrationPreferencesProvider).habits, isFalse);
    });
  });
}
