import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
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
    test('allEnabled has every switch on, haptics on, per-type defaults', () {
      const prefs = CelebrationPreferences.allEnabled();
      expect(prefs.enabled, isTrue);
      expect(prefs.haptics, isTrue);
      expect(prefs.habits, isTrue);
      expect(prefs.checklistItems, isTrue);
      expect(prefs.tasks, isTrue);
      // Each content type carries its own product-default variant.
      expect(prefs.tasksVariant, CelebrationPreferences.defaultTasksVariant);
      expect(prefs.habitsVariant, CelebrationPreferences.defaultHabitsVariant);
      expect(
        prefs.checklistItemsVariant,
        CelebrationPreferences.defaultChecklistItemsVariant,
      );
      // The defaults are deliberately distinct per surface.
      expect(prefs.tasksVariant, CelebrationVariant.sparks);
      expect(prefs.habitsVariant, CelebrationVariant.confetti);
      expect(prefs.checklistItemsVariant, CelebrationVariant.bubbles);
    });

    test('copyWith replaces only the named field, with value equality', () {
      const base = CelebrationPreferences.allEnabled();
      final tasksOff = base.copyWith(tasks: false);

      expect(tasksOff.tasks, isFalse);
      expect(tasksOff.habits, isTrue);
      expect(tasksOff.checklistItems, isTrue);
      expect(tasksOff.enabled, isTrue);
      expect(tasksOff.haptics, isTrue);
      expect(tasksOff, isNot(base));
      // Two independently-built equal values compare equal and hash equally.
      expect(tasksOff, base.copyWith(tasks: false));
      expect(tasksOff.hashCode, base.copyWith(tasks: false).hashCode);
    });

    test('copyWith carries each per-type variant and equality tracks it', () {
      const base = CelebrationPreferences.allEnabled();
      final tasksFireworks = base.copyWith(
        tasksVariant: CelebrationVariant.fireworks,
      );

      expect(tasksFireworks.tasksVariant, CelebrationVariant.fireworks);
      // The other two variants are untouched.
      expect(tasksFireworks.habitsVariant, base.habitsVariant);
      expect(tasksFireworks.checklistItemsVariant, base.checklistItemsVariant);
      expect(tasksFireworks, isNot(base));
      expect(tasksFireworks.hashCode, isNot(base.hashCode));
      expect(
        tasksFireworks,
        base.copyWith(tasksVariant: CelebrationVariant.fireworks),
      );
    });

    test('each per-type variant is distinguished by equality', () {
      const base = CelebrationPreferences.allEnabled();
      final habits = base.copyWith(habitsVariant: CelebrationVariant.embers);
      final checklist = base.copyWith(
        checklistItemsVariant: CelebrationVariant.embers,
      );
      expect(habits, isNot(base));
      expect(checklist, isNot(base));
      expect(habits, isNot(checklist));
    });

    test('enabled and haptics are distinguished by equality', () {
      const base = CelebrationPreferences.allEnabled();
      expect(base.copyWith(enabled: false), isNot(base));
      expect(base.copyWith(haptics: false), isNot(base));
      expect(
        base.copyWith(enabled: false),
        isNot(base.copyWith(haptics: false)),
      );
    });

    group('animate getters fold the master switch into each event', () {
      test('all true when master + the event are on', () {
        const prefs = CelebrationPreferences.allEnabled();
        expect(prefs.animateHabits, isTrue);
        expect(prefs.animateChecklistItems, isTrue);
        expect(prefs.animateTasks, isTrue);
      });

      test('the master switch off forces every animate getter false', () {
        final off = const CelebrationPreferences.allEnabled().copyWith(
          enabled: false,
        );
        expect(off.animateHabits, isFalse);
        expect(off.animateChecklistItems, isFalse);
        expect(off.animateTasks, isFalse);
        // The per-event fields keep their own (on) value underneath.
        expect(off.habits, isTrue);
        expect(off.checklistItems, isTrue);
        expect(off.tasks, isTrue);
      });

      test('a single event off only zeroes its own animate getter', () {
        final tasksOff = const CelebrationPreferences.allEnabled().copyWith(
          tasks: false,
        );
        expect(tasksOff.animateTasks, isFalse);
        expect(tasksOff.animateHabits, isTrue);
        expect(tasksOff.animateChecklistItems, isTrue);
      });

      test('haptics do not influence the visual animate getters', () {
        final noHaptics = const CelebrationPreferences.allEnabled().copyWith(
          haptics: false,
        );
        expect(noHaptics.animateHabits, isTrue);
        expect(noHaptics.animateChecklistItems, isTrue);
        expect(noHaptics.animateTasks, isTrue);
      });
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

    test('hydrates a persisted master "false" into enabled', () async {
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_ENABLED'),
      ).thenAnswer((_) async => 'false');
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container
        ..listen(celebrationPreferencesControllerProvider, (_, next) {
          if (!completer.isCompleted && !next.enabled) completer.complete(next);
        })
        ..read(celebrationPreferencesControllerProvider);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(result.enabled, isFalse);
      // The per-event switches keep their on default underneath the master.
      expect(result.habits, isTrue);
      expect(result.checklistItems, isTrue);
      expect(result.tasks, isTrue);
    });

    test('hydrates a persisted haptics "false" into haptics', () async {
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_HAPTICS'),
      ).thenAnswer((_) async => 'false');
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container
        ..listen(celebrationPreferencesControllerProvider, (_, next) {
          if (!completer.isCompleted && !next.haptics) completer.complete(next);
        })
        ..read(celebrationPreferencesControllerProvider);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(result.haptics, isFalse);
      expect(result.enabled, isTrue);
    });

    test('hydrates a persisted per-type variant name', () async {
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_VARIANT_HABITS'),
      ).thenAnswer((_) async => CelebrationVariant.embers.name);
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container
        ..listen(celebrationPreferencesControllerProvider, (_, next) {
          if (!completer.isCompleted &&
              next.habitsVariant == CelebrationVariant.embers) {
            completer.complete(next);
          }
        })
        ..read(celebrationPreferencesControllerProvider);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(result.habitsVariant, CelebrationVariant.embers);
      // The other two keep their own defaults — the per-type key is targeted.
      expect(result.tasksVariant, CelebrationPreferences.defaultTasksVariant);
      expect(
        result.checklistItemsVariant,
        CelebrationPreferences.defaultChecklistItemsVariant,
      );
    });

    test(
      'migrates the legacy global variant onto every unset per-type key',
      () async {
        container.dispose();
        await tearDownTestGetIt();
        final mocks = await setUpTestGetIt();
        when(
          () => mocks.settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);
        // A pre-split install only has the old global key set.
        when(
          () => mocks.settingsDb.itemByKey('CELEBRATE_VARIANT'),
        ).thenAnswer((_) async => CelebrationVariant.fireworks.name);
        container = ProviderContainer();

        final completer = Completer<CelebrationPreferences>();
        container
          ..listen(celebrationPreferencesControllerProvider, (_, next) {
            if (!completer.isCompleted &&
                next.tasksVariant == CelebrationVariant.fireworks) {
              completer.complete(next);
            }
          })
          ..read(celebrationPreferencesControllerProvider);

        final result = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        // The chosen global style seeds all three, overriding the per-type
        // defaults so the upgrade preserves the user's choice everywhere.
        expect(result.tasksVariant, CelebrationVariant.fireworks);
        expect(result.habitsVariant, CelebrationVariant.fireworks);
        expect(result.checklistItemsVariant, CelebrationVariant.fireworks);
      },
    );

    test('a per-type key wins over the legacy global key', () async {
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_VARIANT'),
      ).thenAnswer((_) async => CelebrationVariant.fireworks.name);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_VARIANT_TASKS'),
      ).thenAnswer((_) async => CelebrationVariant.embers.name);
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container
        ..listen(celebrationPreferencesControllerProvider, (_, next) {
          if (!completer.isCompleted &&
              next.tasksVariant == CelebrationVariant.embers) {
            completer.complete(next);
          }
        })
        ..read(celebrationPreferencesControllerProvider);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      // Tasks took its own key; habits/checklists migrated from the legacy one.
      expect(result.tasksVariant, CelebrationVariant.embers);
      expect(result.habitsVariant, CelebrationVariant.fireworks);
      expect(result.checklistItemsVariant, CelebrationVariant.fireworks);
    });

    test('an unrecognised per-type variant falls back to its default', () async {
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      // A real read lands, but the stored value is junk from another build, and
      // there is no legacy global to fall back to.
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_VARIANT_TASKS'),
      ).thenAnswer((_) async => 'supernova');
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_TASKS'),
      ).thenAnswer((_) async => 'false');
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container
        ..listen(celebrationPreferencesControllerProvider, (_, next) {
          // Wait for the (real) hydration to land via the tasks=off signal.
          if (!completer.isCompleted && !next.tasks) completer.complete(next);
        })
        ..read(celebrationPreferencesControllerProvider);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(
        result.tasksVariant,
        CelebrationPreferences.defaultTasksVariant,
      );
    });

    test(
      'toggling one switch before hydration completes still hydrates the rest',
      () async {
        container.dispose();
        await tearDownTestGetIt();
        final mocks = await setUpTestGetIt();
        when(
          () => mocks.settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);
        // Habits + tasks were previously turned off and persisted.
        when(
          () => mocks.settingsDb.itemByKey('CELEBRATE_HABITS'),
        ).thenAnswer((_) async => 'false');
        when(
          () => mocks.settingsDb.itemByKey('CELEBRATE_TASKS'),
        ).thenAnswer((_) async => 'false');
        container = ProviderContainer();

        // build() schedules hydration; toggle checklist items before its
        // async reads resolve.
        final notifier = container.read(
          celebrationPreferencesControllerProvider.notifier,
        );
        final completer = Completer<CelebrationPreferences>();
        container.listen(celebrationPreferencesControllerProvider, (_, next) {
          // Hydration has landed once the persisted habits=off is reflected.
          if (!completer.isCompleted && !next.habits) completer.complete(next);
        });
        await notifier.setChecklistItems(enabled: false);

        final result = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        // The in-session toggle stuck …
        expect(result.checklistItems, isFalse);
        // … and it did NOT block the other two from hydrating their saved
        // values (the bug the per-field guard fixes).
        expect(result.habits, isFalse);
        expect(result.tasks, isFalse);
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

    test('setEnabled(false) flips the master and persists "false"', () async {
      await container
          .read(celebrationPreferencesControllerProvider.notifier)
          .setEnabled(enabled: false);

      final prefs = container.read(celebrationPreferencesControllerProvider);
      expect(prefs.enabled, isFalse);
      // The per-event switches are untouched; only the master moved.
      expect(prefs.habits, isTrue);
      expect(prefs.animateHabits, isFalse);
      verify(
        () =>
            getIt<SettingsDb>().saveSettingsItem('CELEBRATE_ENABLED', 'false'),
      ).called(1);
    });

    test('setHaptics(false) flips haptics without touching visuals', () async {
      await container
          .read(celebrationPreferencesControllerProvider.notifier)
          .setHaptics(enabled: false);

      final prefs = container.read(celebrationPreferencesControllerProvider);
      expect(prefs.haptics, isFalse);
      expect(prefs.enabled, isTrue);
      expect(prefs.animateTasks, isTrue);
      verify(
        () =>
            getIt<SettingsDb>().saveSettingsItem('CELEBRATE_HAPTICS', 'false'),
      ).called(1);
    });

    test('each per-type setter persists only its own key', () async {
      final notifier = container.read(
        celebrationPreferencesControllerProvider.notifier,
      );
      await notifier.setTasksVariant(CelebrationVariant.fireworks);
      await notifier.setHabitsVariant(CelebrationVariant.embers);
      await notifier.setChecklistItemsVariant(CelebrationVariant.sparks);

      final prefs = container.read(celebrationPreferencesControllerProvider);
      expect(prefs.tasksVariant, CelebrationVariant.fireworks);
      expect(prefs.habitsVariant, CelebrationVariant.embers);
      expect(prefs.checklistItemsVariant, CelebrationVariant.sparks);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          'CELEBRATE_VARIANT_TASKS',
          'fireworks',
        ),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          'CELEBRATE_VARIANT_HABITS',
          'embers',
        ),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          'CELEBRATE_VARIANT_CHECKLIST_ITEMS',
          'sparks',
        ),
      ).called(1);
      // The legacy global key is never written.
      verifyNever(
        () => getIt<SettingsDb>().saveSettingsItem('CELEBRATE_VARIANT', any()),
      );
    });

    test(
      'master, haptics and a variant choice coexist independently',
      () async {
        final notifier = container.read(
          celebrationPreferencesControllerProvider.notifier,
        );
        await notifier.setEnabled(enabled: false);
        await notifier.setHaptics(enabled: false);
        await notifier.setHabitsVariant(CelebrationVariant.bubbles);

        final prefs = container.read(celebrationPreferencesControllerProvider);
        expect(prefs.enabled, isFalse);
        expect(prefs.haptics, isFalse);
        expect(prefs.habitsVariant, CelebrationVariant.bubbles);
      },
    );
  });

  group('persistence resilience', () {
    test(
      'a setter still updates state when SettingsDb is unregistered',
      () async {
        // Drop SettingsDb so the persist path is skipped entirely.
        if (getIt.isRegistered<SettingsDb>()) {
          getIt.unregister<SettingsDb>();
        }

        await container
            .read(celebrationPreferencesControllerProvider.notifier)
            .setTasksVariant(CelebrationVariant.confetti);

        expect(
          container.read(celebrationPreferencesControllerProvider).tasksVariant,
          CelebrationVariant.confetti,
        );
      },
    );

    test('a write that throws leaves the in-memory toggle applied', () async {
      when(
        () =>
            getIt<SettingsDb>().saveSettingsItem('CELEBRATE_ENABLED', 'false'),
      ).thenThrow(Exception('disk full'));

      await container
          .read(celebrationPreferencesControllerProvider.notifier)
          .setEnabled(enabled: false);

      expect(
        container.read(celebrationPreferencesControllerProvider).enabled,
        isFalse,
      );
    });
  });
}
