import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
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
      expect(
        prefs.tasksSelection,
        const FixedSelection(CelebrationPreferences.defaultTasksVariant),
      );
      expect(
        prefs.habitsSelection,
        const FixedSelection(CelebrationPreferences.defaultHabitsVariant),
      );
      expect(
        prefs.checklistItemsSelection,
        const FixedSelection(
          CelebrationPreferences.defaultChecklistItemsVariant,
        ),
      );
      // The defaults are deliberately distinct per surface.
      expect(
        prefs.tasksSelection,
        const FixedSelection(CelebrationVariant.sparks),
      );
      expect(
        prefs.habitsSelection,
        const FixedSelection(CelebrationVariant.confetti),
      );
      expect(
        prefs.checklistItemsSelection,
        const FixedSelection(CelebrationVariant.bubbles),
      );
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
        tasksSelection: const FixedSelection(CelebrationVariant.fireworks),
      );

      expect(
        tasksFireworks.tasksSelection,
        const FixedSelection(CelebrationVariant.fireworks),
      );
      // The other two variants are untouched.
      expect(tasksFireworks.habitsSelection, base.habitsSelection);
      expect(
        tasksFireworks.checklistItemsSelection,
        base.checklistItemsSelection,
      );
      expect(tasksFireworks, isNot(base));
      expect(tasksFireworks.hashCode, isNot(base.hashCode));
      expect(
        tasksFireworks,
        base.copyWith(
          tasksSelection: const FixedSelection(CelebrationVariant.fireworks),
        ),
      );
    });

    test('each per-type variant is distinguished by equality', () {
      const base = CelebrationPreferences.allEnabled();
      final habits = base.copyWith(
        habitsSelection: const FixedSelection(CelebrationVariant.embers),
      );
      final checklist = base.copyWith(
        checklistItemsSelection: const FixedSelection(
          CelebrationVariant.embers,
        ),
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
              next.habitsSelection ==
                  const FixedSelection(CelebrationVariant.embers)) {
            completer.complete(next);
          }
        })
        ..read(celebrationPreferencesControllerProvider);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(
        result.habitsSelection,
        const FixedSelection(CelebrationVariant.embers),
      );
      // The other two keep their own defaults — the per-type key is targeted.
      expect(
        result.tasksSelection,
        const FixedSelection(CelebrationPreferences.defaultTasksVariant),
      );
      expect(
        result.checklistItemsSelection,
        const FixedSelection(
          CelebrationPreferences.defaultChecklistItemsVariant,
        ),
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
                next.tasksSelection ==
                    const FixedSelection(CelebrationVariant.fireworks)) {
              completer.complete(next);
            }
          })
          ..read(celebrationPreferencesControllerProvider);

        final result = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        // The chosen global style seeds all three, overriding the per-type
        // defaults so the upgrade preserves the user's choice everywhere.
        expect(
          result.tasksSelection,
          const FixedSelection(CelebrationVariant.fireworks),
        );
        expect(
          result.habitsSelection,
          const FixedSelection(CelebrationVariant.fireworks),
        );
        expect(
          result.checklistItemsSelection,
          const FixedSelection(CelebrationVariant.fireworks),
        );
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
              next.tasksSelection ==
                  const FixedSelection(CelebrationVariant.embers)) {
            completer.complete(next);
          }
        })
        ..read(celebrationPreferencesControllerProvider);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      // Tasks took its own key; habits/checklists migrated from the legacy one.
      expect(
        result.tasksSelection,
        const FixedSelection(CelebrationVariant.embers),
      );
      expect(
        result.habitsSelection,
        const FixedSelection(CelebrationVariant.fireworks),
      );
      expect(
        result.checklistItemsSelection,
        const FixedSelection(CelebrationVariant.fireworks),
      );
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
        result.tasksSelection,
        const FixedSelection(CelebrationPreferences.defaultTasksVariant),
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
      await notifier.setTasksSelection(
        const FixedSelection(CelebrationVariant.fireworks),
      );
      await notifier.setHabitsSelection(
        const FixedSelection(CelebrationVariant.embers),
      );
      await notifier.setChecklistItemsSelection(
        const FixedSelection(CelebrationVariant.sparks),
      );

      final prefs = container.read(celebrationPreferencesControllerProvider);
      expect(
        prefs.tasksSelection,
        const FixedSelection(CelebrationVariant.fireworks),
      );
      expect(
        prefs.habitsSelection,
        const FixedSelection(CelebrationVariant.embers),
      );
      expect(
        prefs.checklistItemsSelection,
        const FixedSelection(CelebrationVariant.sparks),
      );
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
        await notifier.setHabitsSelection(
          const FixedSelection(CelebrationVariant.bubbles),
        );

        final prefs = container.read(celebrationPreferencesControllerProvider);
        expect(prefs.enabled, isFalse);
        expect(prefs.haptics, isFalse);
        expect(
          prefs.habitsSelection,
          const FixedSelection(CelebrationVariant.bubbles),
        );
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
            .setTasksSelection(
              const FixedSelection(CelebrationVariant.confetti),
            );

        expect(
          container
              .read(celebrationPreferencesControllerProvider)
              .tasksSelection,
          const FixedSelection(CelebrationVariant.confetti),
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

  group('variant params', () {
    test('paramsFor falls back to defaults for an untouched variant', () {
      final prefs = container.read(celebrationPreferencesControllerProvider);
      expect(
        prefs.paramsFor(CelebrationVariant.embers),
        CelebrationParams.defaultsFor(CelebrationVariant.embers),
      );
    });

    test(
      'setVariantParams stores the tuned look and persists its JSON',
      () async {
        final tuned = CelebrationParams.defaultsFor(
          CelebrationVariant.confetti,
        ).withValue('count', 12).withValue('spin', 2);
        await container
            .read(celebrationPreferencesControllerProvider.notifier)
            .setVariantParams(tuned);

        final prefs = container.read(celebrationPreferencesControllerProvider);
        expect(prefs.paramsFor(CelebrationVariant.confetti), tuned);
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            'CELEBRATE_PARAMS_confetti',
            tuned.encode(),
          ),
        ).called(1);
      },
    );

    test('resetVariantParams restores the variant to its defaults', () async {
      final notifier = container.read(
        celebrationPreferencesControllerProvider.notifier,
      );
      await notifier.setVariantParams(
        CelebrationParams.defaultsFor(
          CelebrationVariant.sparks,
        ).withValue('gravity', 0.5),
      );
      await notifier.resetVariantParams(CelebrationVariant.sparks);

      final prefs = container.read(celebrationPreferencesControllerProvider);
      final reset = prefs.paramsFor(CelebrationVariant.sparks);
      expect(reset, CelebrationParams.defaultsFor(CelebrationVariant.sparks));
      expect(reset.isCustomized, isFalse);
      // A reset clears the override entirely — the map holds only customized
      // variants, and an empty value is persisted so the key reads "untouched"
      // (and never freezes today's defaults against a future default change).
      expect(
        prefs.variantParams.containsKey(CelebrationVariant.sparks),
        isFalse,
      );
      verify(
        () =>
            getIt<SettingsDb>().saveSettingsItem('CELEBRATE_PARAMS_sparks', ''),
      ).called(1);
    });

    test('hydration drops a blob whose variant disagrees with its key', () async {
      // A corrupt / hand-edited row under the sparks key carrying confetti's
      // payload would otherwise render sparks with confetti's knobs.
      final mismatched = CelebrationParams.defaultsFor(
        CelebrationVariant.confetti,
      ).withValue('count', 9);
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_PARAMS_sparks'),
      ).thenAnswer((_) async => mismatched.encode());
      // A companion key that flips on hydration; the controller sets every field
      // in one emission, so waiting for this tells us hydration has completed.
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_ENABLED'),
      ).thenAnswer((_) async => 'false');
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container.listen(celebrationPreferencesControllerProvider, (_, next) {
        if (!completer.isCompleted && !next.enabled) completer.complete(next);
      }, fireImmediately: true);
      final prefs = await completer.future.timeout(const Duration(seconds: 1));

      // Hydration ran (enabled is now false) yet sparks stayed on its own
      // defaults rather than adopting the confetti payload.
      expect(
        prefs.paramsFor(CelebrationVariant.sparks),
        CelebrationParams.defaultsFor(CelebrationVariant.sparks),
      );
      expect(
        prefs.variantParams.containsKey(CelebrationVariant.sparks),
        isFalse,
      );
    });

    test('hydrates stored tuned params for a variant', () async {
      final tuned = CelebrationParams.defaultsFor(
        CelebrationVariant.sparks,
      ).withValue('gravity', 0.42);
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_PARAMS_sparks'),
      ).thenAnswer((_) async => tuned.encode());
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container.listen(celebrationPreferencesControllerProvider, (_, next) {
        if (!completer.isCompleted &&
            next.paramsFor(CelebrationVariant.sparks) == tuned) {
          completer.complete(next);
        }
      }, fireImmediately: true);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(result.paramsFor(CelebrationVariant.sparks), tuned);
    });

    test(
      'a variant tuned before hydration completes is not overwritten',
      () async {
        container.dispose();
        await tearDownTestGetIt();
        final mocks = await setUpTestGetIt();
        when(
          () => mocks.settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);
        // A persisted signal so we know the (async) hydration has landed; the
        // sparks params key is absent in storage.
        when(
          () => mocks.settingsDb.itemByKey('CELEBRATE_HABITS'),
        ).thenAnswer((_) async => 'false');
        container = ProviderContainer();

        // build() schedules hydration; tune sparks before its async reads resolve.
        final notifier = container.read(
          celebrationPreferencesControllerProvider.notifier,
        );
        final tuned = CelebrationParams.defaultsFor(
          CelebrationVariant.sparks,
        ).withValue('count', 12);
        final completer = Completer<CelebrationPreferences>();
        container.listen(celebrationPreferencesControllerProvider, (_, next) {
          if (!completer.isCompleted && !next.habits) completer.complete(next);
        });
        await notifier.setVariantParams(tuned);

        final result = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        // The in-session tuning stuck (hydration kept the adjusted variant) …
        expect(result.paramsFor(CelebrationVariant.sparks), tuned);
        // … and did not block the rest of hydration from landing.
        expect(result.habits, isFalse);
      },
    );
  });

  group('surprise-mode selection', () {
    test(
      'setTasksSelection(random) persists the random sentinel token',
      () async {
        await container
            .read(celebrationPreferencesControllerProvider.notifier)
            .setTasksSelection(CelebrationSelection.random);

        expect(
          container
              .read(celebrationPreferencesControllerProvider)
              .tasksSelection,
          const RandomSelection(),
        );
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            'CELEBRATE_VARIANT_TASKS',
            CelebrationSelection.randomToken,
          ),
        ).called(1);
      },
    );

    test(
      'setHabitsSelection(combine) persists the combine sentinel token',
      () async {
        await container
            .read(celebrationPreferencesControllerProvider.notifier)
            .setHabitsSelection(CelebrationSelection.combine);

        expect(
          container
              .read(celebrationPreferencesControllerProvider)
              .habitsSelection,
          const CombineSelection(),
        );
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            'CELEBRATE_VARIANT_HABITS',
            CelebrationSelection.combineToken,
          ),
        ).called(1);
      },
    );

    test('hydrates a stored random selection token', () async {
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mocks.settingsDb.itemByKey('CELEBRATE_VARIANT_TASKS'),
      ).thenAnswer((_) async => CelebrationSelection.randomToken);
      container = ProviderContainer();

      final completer = Completer<CelebrationPreferences>();
      container.listen(celebrationPreferencesControllerProvider, (_, next) {
        if (!completer.isCompleted &&
            next.tasksSelection == const RandomSelection()) {
          completer.complete(next);
        }
      }, fireImmediately: true);

      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(result.tasksSelection, const RandomSelection());
    });
  });
}
