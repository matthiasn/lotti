import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_width_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Hydrates the notifier (triggers the async load) and drains the
/// microtask queue so the mocked `itemsByKeys` completes. Mirrors
/// the `_awaitHydration` helper in the shared pane-width tests.
Future<double> _awaitHydration(ProviderContainer container) async {
  container.read(settingsTreeNavWidthProvider);
  for (var i = 0; i < 16; i++) {
    await Future<void>.value();
  }
  return container.read(settingsTreeNavWidthProvider);
}

Future<ProviderContainer> _containerWith({String? persistedValue}) async {
  await tearDownTestGetIt();
  final mocks = await setUpTestGetIt();
  when(
    () => mocks.settingsDb.itemsByKeys(any()),
  ).thenAnswer(
    (_) async => <String, String?>{
      settingsTreeNavWidthKey: persistedValue,
    },
  );
  return ProviderContainer();
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpTestGetIt();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  group('SettingsTreeNavWidth — initial state', () {
    test('builds to defaultSettingsTreeNavWidth with no persisted value', () {
      expect(
        container.read(settingsTreeNavWidthProvider),
        defaultSettingsTreeNavWidth,
      );
    });
  });

  group('SettingsTreeNavWidth — hydration', () {
    test('adopts a valid persisted value on load', () async {
      final c = await _containerWith(persistedValue: '412.0');
      addTearDown(c.dispose);
      expect(await _awaitHydration(c), 412.0);
    });

    test('clamps a persisted value above the maximum', () async {
      final c = await _containerWith(persistedValue: '999.0');
      addTearDown(c.dispose);
      expect(await _awaitHydration(c), maxSettingsTreeNavWidth);
    });

    test('clamps a persisted value below the minimum', () async {
      final c = await _containerWith(persistedValue: '10.0');
      addTearDown(c.dispose);
      expect(await _awaitHydration(c), minSettingsTreeNavWidth);
    });

    test('non-numeric persisted value falls back to default', () async {
      final c = await _containerWith(persistedValue: 'not-a-number');
      addTearDown(c.dispose);
      expect(await _awaitHydration(c), defaultSettingsTreeNavWidth);
    });

    test('infinite persisted value falls back to default', () async {
      // `double.tryParse('Infinity')` returns `double.infinity`; the
      // abbreviation `'inf'` is not a recognized literal and would
      // return `null`, exercising the wrong branch.
      final c = await _containerWith(persistedValue: 'Infinity');
      addTearDown(c.dispose);
      expect(await _awaitHydration(c), defaultSettingsTreeNavWidth);
    });

    test('null (absent key) persisted value keeps the default without '
        'reassigning state', () async {
      final c = await _containerWith();
      addTearDown(c.dispose);
      expect(await _awaitHydration(c), defaultSettingsTreeNavWidth);
    });

    test('user mutation before hydration wins — persisted value does not '
        'clobber it', () async {
      final c = await _containerWith(persistedValue: '412.0');
      addTearDown(c.dispose);
      c.read(settingsTreeNavWidthProvider.notifier).setTo(300);
      expect(await _awaitHydration(c), 300);
    });
  });

  group('SettingsTreeNavWidth.updateBy', () {
    test('positive delta moves width up and clamps at the maximum', () {
      final notifier = container.read(settingsTreeNavWidthProvider.notifier)
        ..updateBy(100);
      expect(
        container.read(settingsTreeNavWidthProvider),
        defaultSettingsTreeNavWidth + 100,
      );
      notifier.updateBy(1000);
      expect(
        container.read(settingsTreeNavWidthProvider),
        maxSettingsTreeNavWidth,
      );
    });

    test('negative delta moves width down and clamps at the minimum', () {
      final notifier = container.read(settingsTreeNavWidthProvider.notifier)
        ..updateBy(-20);
      expect(
        container.read(settingsTreeNavWidthProvider),
        defaultSettingsTreeNavWidth - 20,
      );
      notifier.updateBy(-1000);
      expect(
        container.read(settingsTreeNavWidthProvider),
        minSettingsTreeNavWidth,
      );
    });

    test('zero delta leaves state identity intact (no mutation)', () {
      final notifier = container.read(settingsTreeNavWidthProvider.notifier);
      final first = container.read(settingsTreeNavWidthProvider);
      notifier.updateBy(0);
      expect(
        identical(container.read(settingsTreeNavWidthProvider), first),
        isTrue,
      );
    });
  });

  group('SettingsTreeNavWidth.setTo', () {
    test('valid absolute value is applied', () {
      container.read(settingsTreeNavWidthProvider.notifier).setTo(400);
      expect(container.read(settingsTreeNavWidthProvider), 400);
    });

    test('value above maximum is clamped to max', () {
      container.read(settingsTreeNavWidthProvider.notifier).setTo(600);
      expect(
        container.read(settingsTreeNavWidthProvider),
        maxSettingsTreeNavWidth,
      );
    });

    test('value below minimum is clamped to min', () {
      container.read(settingsTreeNavWidthProvider.notifier).setTo(0);
      expect(
        container.read(settingsTreeNavWidthProvider),
        minSettingsTreeNavWidth,
      );
    });

    test('non-finite value is ignored', () {
      container.read(settingsTreeNavWidthProvider.notifier)
        ..setTo(double.infinity)
        ..setTo(double.nan);
      expect(
        container.read(settingsTreeNavWidthProvider),
        defaultSettingsTreeNavWidth,
      );
    });
  });

  group('SettingsTreeNavWidth.resetToDefault', () {
    test('from a non-default value: returns to default', () {
      container.read(settingsTreeNavWidthProvider.notifier)
        ..setTo(400)
        ..resetToDefault();
      expect(
        container.read(settingsTreeNavWidthProvider),
        defaultSettingsTreeNavWidth,
      );
    });

    test('at default: leaves state identity intact', () {
      final notifier = container.read(settingsTreeNavWidthProvider.notifier);
      final first = container.read(settingsTreeNavWidthProvider);
      notifier.resetToDefault();
      expect(
        identical(container.read(settingsTreeNavWidthProvider), first),
        isTrue,
      );
    });
  });

  group('SettingsTreeNavWidth — debounced persistence', () {
    test(
      'rapid drag-style mutations coalesce into a single persist after the '
      'debounce window',
      () {
        fakeAsync((async) {
          final mock = getIt<SettingsDb>() as MockSettingsDb;
          container.read(settingsTreeNavWidthProvider.notifier)
            ..updateBy(10)
            ..updateBy(10)
            ..updateBy(10);
          async.elapse(settingsTreeNavWidthPersistDebounce ~/ 2);
          verifyNever(() => mock.saveSettingsItem(any(), any()));

          async.elapse(settingsTreeNavWidthPersistDebounce);
          // One persist — all three updates collapsed into the single
          // trailing-edge write carrying the final value.
          verify(
            () => mock.saveSettingsItem(
              settingsTreeNavWidthKey,
              (defaultSettingsTreeNavWidth + 30).toStringAsFixed(1),
            ),
          ).called(1);
          expect(
            container.read(settingsTreeNavWidthProvider),
            defaultSettingsTreeNavWidth + 30,
          );
        });
      },
    );

    test('resetToDefault cancels the debounce and persists immediately', () {
      fakeAsync((async) {
        final mock = getIt<SettingsDb>() as MockSettingsDb;
        container.read(settingsTreeNavWidthProvider.notifier)
          // First schedule a debounced 400-px persist, then flip to
          // the immediate-write reset path and confirm the scheduled
          // write is superseded.
          ..setTo(400)
          ..resetToDefault();
        async.flushMicrotasks();

        // Only the default-width write fires; the scheduled 400-px
        // persist never runs.
        verify(
          () => mock.saveSettingsItem(
            settingsTreeNavWidthKey,
            defaultSettingsTreeNavWidth.toStringAsFixed(1),
          ),
        ).called(1);
        verifyNever(
          () => mock.saveSettingsItem(
            settingsTreeNavWidthKey,
            400.0.toStringAsFixed(1),
          ),
        );

        // Further elapse proves the cancelled debounce never fires
        // — no extra persist for the interim 400-px value.
        async.elapse(settingsTreeNavWidthPersistDebounce * 2);
        verifyNever(
          () => mock.saveSettingsItem(
            settingsTreeNavWidthKey,
            400.0.toStringAsFixed(1),
          ),
        );

        expect(
          container.read(settingsTreeNavWidthProvider),
          defaultSettingsTreeNavWidth,
        );
      });
    });
  });

  group('SettingsTreeNavWidth — bounds constants', () {
    test('spec-declared range 280..480 with default 340', () {
      expect(minSettingsTreeNavWidth, 280);
      expect(maxSettingsTreeNavWidth, 480);
      expect(defaultSettingsTreeNavWidth, 340);
    });

    test('keyboard steps match spec §3.1 (8 / 32 dp)', () {
      expect(settingsTreeNavWidthArrowStep, 8);
      expect(settingsTreeNavWidthShiftArrowStep, 32);
    });
  });

  group('SettingsTreeNavWidth — error handling', () {
    test(
      'a thrown SettingsDb load is swallowed; the notifier keeps the default',
      () async {
        await tearDownTestGetIt();
        final mocks = await setUpTestGetIt();
        when(
          () => mocks.settingsDb.itemsByKeys(any()),
        ).thenThrow(StateError('disk read failed'));
        final c = ProviderContainer();
        addTearDown(c.dispose);

        // Read the provider to trigger the async hydration, then drain.
        c.read(settingsTreeNavWidthProvider);
        for (var i = 0; i < 16; i++) {
          await Future<void>.value();
        }

        // Hydration failure must not leak the StateError out of the
        // notifier — the user just sees the default width.
        expect(
          c.read(settingsTreeNavWidthProvider),
          defaultSettingsTreeNavWidth,
        );
      },
    );

    test(
      'a thrown SettingsDb save is swallowed; in-memory state still moves',
      () async {
        await tearDownTestGetIt();
        final mocks = await setUpTestGetIt();
        when(
          () => mocks.settingsDb.itemsByKeys(any()),
        ).thenAnswer((_) async => <String, String?>{});
        when(
          () => mocks.settingsDb.saveSettingsItem(any(), any()),
        ).thenThrow(StateError('disk write failed'));

        final c = ProviderContainer();
        addTearDown(c.dispose);
        // Hydrate.
        c.read(settingsTreeNavWidthProvider);
        for (var i = 0; i < 16; i++) {
          await Future<void>.value();
        }

        // resetToDefault flushes the debounce and persists *now* —
        // bypassing the timer means we don't have to wait real time
        // for the failing write to fire.
        c.read(settingsTreeNavWidthProvider.notifier).updateBy(20);
        expect(
          c.read(settingsTreeNavWidthProvider),
          defaultSettingsTreeNavWidth + 20,
        );
        c.read(settingsTreeNavWidthProvider.notifier).resetToDefault();
        // Drain the unawaited persist so the thrown StateError is
        // funneled into the catch block + LoggingService rather than
        // surfacing as an uncaught async error after the test ends.
        for (var i = 0; i < 16; i++) {
          await Future<void>.value();
        }

        // The thrown StateError must not crash the notifier — the
        // reset still moved state to default in-memory.
        expect(
          c.read(settingsTreeNavWidthProvider),
          defaultSettingsTreeNavWidth,
        );
      },
    );
  });
}
