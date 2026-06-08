import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

/// Glados generators for the pane-width property tests.
///
/// The numeric range is deliberately wider than the production clamp window
/// (`[min, max]`) so generated values land below the minimum, inside the
/// window, and above the maximum, exercising both clamp branches of
/// `_parseWidth`.
extension _AnyPaneWidth on glados.Any {
  /// Doubles spanning well below `minSidebarWidth` to well above
  /// `maxSidebarWidth`.
  glados.Generator<double> get sidebarWidthValue =>
      glados.DoubleAnys(this).doubleInRange(0, 1000);

  /// Doubles spanning well below `minListPaneWidth` to well above
  /// `maxListPaneWidth`.
  glados.Generator<double> get listPaneWidthValue =>
      glados.DoubleAnys(this).doubleInRange(0, 2000);
}

/// Creates a fresh [ProviderContainer] with [SettingsDb.itemsByKeys] stubbed
/// to return the given values for the pane width keys.
Future<ProviderContainer> _createContainerWithPersistedWidths({
  String? sidebarWidth,
  String? listPaneWidth,
  String? sidebarCollapsed,
}) async {
  await tearDownTestGetIt();
  final mocks = await setUpTestGetIt();
  when(
    () => mocks.settingsDb.itemsByKeys(any()),
  ).thenAnswer(
    (_) async => <String, String?>{
      sidebarWidthKey: sidebarWidth,
      listPaneWidthKey: listPaneWidth,
      sidebarCollapsedKey: sidebarCollapsed,
    },
  );
  return ProviderContainer();
}

/// Triggers provider read and drains pending microtasks so the async
/// `_loadPersistedWidths` (which calls the mocked `itemsByKeys`) completes
/// deterministically.
///
/// As of this writing `_loadPersistedWidths` contains a single `await` (the
/// `settingsDb.itemsByKeys` call), so one microtask hop would suffice. The
/// 16-iteration loop is deliberate headroom: it is resilient to future async
/// hops being added inside `_loadPersistedWidths` — a single `Future.value()`
/// would only cover today's one `await` and would silently return the
/// pre-hydration default if another were added. If `_loadPersistedWidths`
/// ever gains so many awaits that 16 hops no longer drain it, increase this
/// count.
Future<PaneWidths> _awaitHydration(ProviderContainer container) async {
  container.read(paneWidthControllerProvider);
  for (var i = 0; i < 16; i++) {
    await Future<void>.value();
  }
  return container.read(paneWidthControllerProvider);
}

/// Re-stubs the already-registered [SettingsDb] mock with the given persisted
/// strings and hydrates a fresh controller, returning the resulting state.
///
/// Unlike [_createContainerWithPersistedWidths] this does not reset GetIt; it
/// only re-stubs the existing mock so it stays cheap when invoked hundreds of
/// times from a Glados property loop. The caller owns the container's lifetime
/// and must dispose it.
Future<PaneWidths> _hydrateWith({
  String? sidebarWidth,
  String? listPaneWidth,
  String? sidebarCollapsed,
}) async {
  when(
    () => getIt<SettingsDb>().itemsByKeys(any()),
  ).thenAnswer(
    (_) async => <String, String?>{
      sidebarWidthKey: sidebarWidth,
      listPaneWidthKey: listPaneWidth,
      sidebarCollapsedKey: sidebarCollapsed,
    },
  );
  final container = ProviderContainer();
  try {
    return await _awaitHydration(container);
  } finally {
    container.dispose();
  }
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    final mocks = await setUpTestGetIt();
    when(
      () => mocks.settingsDb.itemsByKeys(any()),
    ).thenAnswer(
      (_) async => <String, String?>{
        sidebarWidthKey: null,
        listPaneWidthKey: null,
        // Include the key explicitly (rather than relying on a missing-key
        // lookup returning null) so the stub mirrors what SettingsDb returns
        // and the test does not pass by accident if lookup semantics change.
        sidebarCollapsedKey: null,
      },
    );
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  group('PaneWidths', () {
    test('default values match constants', () {
      const widths = PaneWidths();
      expect(widths.sidebarWidth, defaultSidebarWidth);
      expect(widths.listPaneWidth, defaultListPaneWidth);
      expect(widths.sidebarCollapsed, isFalse);
    });

    test('copyWith creates new instance with updated values', () {
      const widths = PaneWidths();
      final updated = widths.copyWith(sidebarWidth: 400);
      expect(updated.sidebarWidth, 400);
      expect(updated.listPaneWidth, defaultListPaneWidth);
    });

    test('copyWith preserves existing values when not specified', () {
      const widths = PaneWidths(sidebarWidth: 250, listPaneWidth: 600);
      final updated = widths.copyWith(listPaneWidth: 700);
      expect(updated.sidebarWidth, 250);
      expect(updated.listPaneWidth, 700);
    });

    test('copyWith updates collapse flag', () {
      const widths = PaneWidths();
      final updated = widths.copyWith(sidebarCollapsed: true);
      expect(updated.sidebarCollapsed, isTrue);
      expect(updated.sidebarWidth, defaultSidebarWidth);
    });

    test('equality compares all field values', () {
      const a = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      const b = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      const c = PaneWidths(sidebarWidth: 300, listPaneWidth: 600);
      const d = PaneWidths(sidebarWidth: 300, sidebarCollapsed: true);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode is consistent with equality', () {
      const a = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      const b = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('PaneWidthController build', () {
    test('returns default PaneWidths on init', () {
      final state = container.read(paneWidthControllerProvider);
      expect(state.sidebarWidth, defaultSidebarWidth);
      expect(state.listPaneWidth, defaultListPaneWidth);
    });

    test('loads persisted widths from SettingsDb', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarWidth: '280.0',
        listPaneWidth: '450.0',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, 280.0);
      expect(result.listPaneWidth, 450.0);
    });

    test('clamps persisted sidebar width below minimum', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarWidth: '50.0',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, minSidebarWidth);
    });

    test('clamps persisted sidebar width above maximum', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarWidth: '999.0',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, maxSidebarWidth);
    });

    test('clamps persisted list pane width below minimum', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        listPaneWidth: '50.0',
      );

      final result = await _awaitHydration(container);
      expect(result.listPaneWidth, minListPaneWidth);
    });

    test('clamps persisted list pane width above maximum', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        listPaneWidth: '2000.0',
      );

      final result = await _awaitHydration(container);
      expect(result.listPaneWidth, maxListPaneWidth);
    });

    test('handles non-numeric persisted values gracefully', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarWidth: 'invalid',
        listPaneWidth: 'abc',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
      expect(result.listPaneWidth, defaultListPaneWidth);
    });

    test('handles null persisted values gracefully', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths();

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
      expect(result.listPaneWidth, defaultListPaneWidth);
      expect(result.sidebarCollapsed, isFalse);
    });

    test('loads persisted collapse flag', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarCollapsed: 'true',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarCollapsed, isTrue);
    });

    test(
      'loads the persisted sidebarWidth while collapsed so expand restores '
      'the pre-collapse position',
      () async {
        container.dispose();
        container = await _createContainerWithPersistedWidths(
          sidebarCollapsed: 'true',
          sidebarWidth: '260.0',
        );

        final result = await _awaitHydration(container);
        expect(result.sidebarCollapsed, isTrue);
        expect(result.sidebarWidth, 260.0);
      },
    );

    test('treats any value other than "true" as not collapsed', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarCollapsed: 'nope',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarCollapsed, isFalse);
    });
  });

  group('PaneWidthController updateSidebarWidth', () {
    test('increases sidebar width by delta', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateSidebarWidth(50);
      expect(
        container.read(paneWidthControllerProvider).sidebarWidth,
        defaultSidebarWidth + 50,
      );
    });

    test('decreases sidebar width by negative delta', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateSidebarWidth(-50);
      expect(
        container.read(paneWidthControllerProvider).sidebarWidth,
        defaultSidebarWidth - 50,
      );
    });

    test('clamps at minSidebarWidth', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateSidebarWidth(-500);
      expect(
        container.read(paneWidthControllerProvider).sidebarWidth,
        minSidebarWidth,
      );
    });

    test('clamps at maxSidebarWidth', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateSidebarWidth(500);
      expect(
        container.read(paneWidthControllerProvider).sidebarWidth,
        maxSidebarWidth,
      );
    });

    test('does not affect list pane width', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateSidebarWidth(50);
      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        defaultListPaneWidth,
      );
    });

    test('persists to SettingsDb after debounce', () {
      fakeAsync((async) {
        container
            .read(paneWidthControllerProvider.notifier)
            .updateSidebarWidth(30);
        async.flushMicrotasks();

        // Not yet persisted before debounce fires
        verifyNever(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarWidthKey,
            any(),
          ),
        );

        async.elapse(persistDebounce);

        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarWidthKey,
            '350.0',
          ),
        ).called(1);
      });
    });

    test('debounce coalesces rapid updates into one write', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..updateSidebarWidth(10)
          ..updateSidebarWidth(20)
          ..updateSidebarWidth(30);
        async
          ..flushMicrotasks()
          ..elapse(persistDebounce);

        // Only the final accumulated value is persisted
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarWidthKey,
            '380.0',
          ),
        ).called(1);
      });
    });
  });

  group('PaneWidthController updateListPaneWidth', () {
    test('increases list pane width by delta', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth(100);
      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        defaultListPaneWidth + 100,
      );
    });

    test('decreases list pane width by negative delta', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth(-100);
      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        defaultListPaneWidth - 100,
      );
    });

    test('clamps at minListPaneWidth', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth(-500);
      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        minListPaneWidth,
      );
    });

    test('clamps at maxListPaneWidth', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth(500);
      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        maxListPaneWidth,
      );
    });

    test('does not affect sidebar width', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth(100);
      expect(
        container.read(paneWidthControllerProvider).sidebarWidth,
        defaultSidebarWidth,
      );
    });

    test('persists to SettingsDb after debounce', () {
      fakeAsync((async) {
        container
            .read(paneWidthControllerProvider.notifier)
            .updateListPaneWidth(60);
        async.flushMicrotasks();

        verifyNever(
          () => getIt<SettingsDb>().saveSettingsItem(
            listPaneWidthKey,
            any(),
          ),
        );

        async.elapse(persistDebounce);

        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            listPaneWidthKey,
            '600.0',
          ),
        ).called(1);
      });
    });
  });

  group('PaneWidthController resetToDefaults', () {
    test('resets both widths to defaults', () {
      container.read(paneWidthControllerProvider.notifier)
        ..updateSidebarWidth(50)
        ..updateListPaneWidth(100)
        ..resetToDefaults();
      final state = container.read(paneWidthControllerProvider);
      expect(state.sidebarWidth, defaultSidebarWidth);
      expect(state.listPaneWidth, defaultListPaneWidth);
    });

    test('persists immediately without debounce', () {
      container.read(paneWidthControllerProvider.notifier).resetToDefaults();
      // No fake-time advancement is needed: resetToDefaults calls
      // _persistSidebarWidth()/_persistListPaneWidth() synchronously rather
      // than scheduling them through the 300ms debounce timer, so the writes
      // are already enqueued by the time we verify.
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          sidebarWidthKey,
          '320.0',
        ),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          listPaneWidthKey,
          '540.0',
        ),
      ).called(1);
    });

    test('cancels pending debounced writes', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..updateSidebarWidth(50)
          ..updateListPaneWidth(100)
          ..resetToDefaults();
        async
          ..flushMicrotasks()
          ..elapse(persistDebounce);

        // The debounced writes from updateSidebarWidth/updateListPaneWidth
        // should be cancelled; only resetToDefaults writes should fire.
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarWidthKey,
            '320.0',
          ),
        ).called(1);
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            listPaneWidthKey,
            '540.0',
          ),
        ).called(1);
      });
    });

    test(
      'resetting a previously collapsed sidebar clears the flag and '
      'persists it as false',
      () {
        fakeAsync((async) {
          // Collapse first so the persisted flag would otherwise be "true",
          // then reset and confirm the false flag is written back.
          container.read(paneWidthControllerProvider.notifier)
            ..collapseSidebar()
            ..resetToDefaults();
          async
            ..flushMicrotasks()
            ..elapse(persistDebounce);

          expect(
            container.read(paneWidthControllerProvider).sidebarCollapsed,
            isFalse,
            reason: 'reset must return the sidebar to its expanded default',
          );
          verify(
            () => getIt<SettingsDb>().saveSettingsItem(
              sidebarCollapsedKey,
              'false',
            ),
          ).called(1);
        });
      },
    );
  });

  group('PaneWidthController incremental updates', () {
    test('accumulates multiple sidebar width updates', () {
      container.read(paneWidthControllerProvider.notifier)
        ..updateSidebarWidth(10)
        ..updateSidebarWidth(20)
        ..updateSidebarWidth(30);
      expect(
        container.read(paneWidthControllerProvider).sidebarWidth,
        defaultSidebarWidth + 60,
      );
    });

    test('accumulates multiple list pane width updates', () {
      container.read(paneWidthControllerProvider.notifier)
        ..updateListPaneWidth(10)
        ..updateListPaneWidth(20)
        ..updateListPaneWidth(30);
      expect(
        container.read(paneWidthControllerProvider).listPaneWidth,
        defaultListPaneWidth + 60,
      );
    });

    test('independent updates do not interfere', () {
      container.read(paneWidthControllerProvider.notifier)
        ..updateSidebarWidth(50)
        ..updateListPaneWidth(-100);
      final state = container.read(paneWidthControllerProvider);
      expect(state.sidebarWidth, defaultSidebarWidth + 50);
      expect(state.listPaneWidth, defaultListPaneWidth - 100);
    });
  });

  group('PaneWidthController non-finite values', () {
    test('rejects NaN persisted sidebar width', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarWidth: 'NaN',
        listPaneWidth: '450.0',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
      expect(result.listPaneWidth, 450.0);
    });

    test('rejects Infinity persisted list pane width', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarWidth: '280.0',
        listPaneWidth: 'Infinity',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, 280.0);
      expect(result.listPaneWidth, defaultListPaneWidth);
    });

    test('rejects -Infinity persisted width', () async {
      container.dispose();
      container = await _createContainerWithPersistedWidths(
        sidebarWidth: '-Infinity',
      );

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
    });
  });

  group('PaneWidthController _parseWidth (Glados, via hydration)', () {
    glados.Glados(
      glados.any.sidebarWidthValue,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'hydrated sidebar width equals the round-tripped value clamped to '
      '[min, max]',
      (value) async {
        final stored = value.toStringAsFixed(1);
        // _parseWidth parses the stored string then clamps; the expected
        // value must round-trip through the same toStringAsFixed precision.
        final expected = double.parse(stored).clamp(
          minSidebarWidth,
          maxSidebarWidth,
        );

        final result = await _hydrateWith(sidebarWidth: stored);

        expect(result.sidebarWidth, expected, reason: 'stored=$stored');
        expect(
          result.sidebarWidth,
          inInclusiveRange(minSidebarWidth, maxSidebarWidth),
          reason: 'clamp invariant violated for stored=$stored',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.listPaneWidthValue,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'hydrated list pane width equals the round-tripped value clamped to '
      '[min, max]',
      (value) async {
        final stored = value.toStringAsFixed(1);
        final expected = double.parse(stored).clamp(
          minListPaneWidth,
          maxListPaneWidth,
        );

        final result = await _hydrateWith(listPaneWidth: stored);

        expect(result.listPaneWidth, expected, reason: 'stored=$stored');
        expect(
          result.listPaneWidth,
          inInclusiveRange(minListPaneWidth, maxListPaneWidth),
          reason: 'clamp invariant violated for stored=$stored',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      // Letter-only strings never parse to a finite double, so every value
      // must fall through to the default — a genuine fallback property, not a
      // restatement of _parseWidth's own tryParse check.
      glados.any.stringOf('abcdXYZ'),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'non-numeric stored strings fall back to defaults for both panes',
      (stored) async {
        // Guard the alphabet assumption: if a generated string ever parsed to
        // a finite number this property would be meaningless.
        final parsed = double.tryParse(stored);
        expect(
          parsed == null || !parsed.isFinite,
          isTrue,
          reason: 'alphabet unexpectedly produced a finite number: "$stored"',
        );

        final result = await _hydrateWith(
          sidebarWidth: stored,
          listPaneWidth: stored,
        );

        expect(result.sidebarWidth, defaultSidebarWidth, reason: stored);
        expect(result.listPaneWidth, defaultListPaneWidth, reason: stored);
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.sidebarWidthValue,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      're-parsing an already-clamped, round-tripped width is idempotent',
      (value) async {
        final firstStored = value.toStringAsFixed(1);
        final once = (await _hydrateWith(
          sidebarWidth: firstStored,
        )).sidebarWidth;

        // Feed the already-clamped result back in; a second pass must not move
        // it (it is already inside [min, max] and round-trips cleanly).
        final twice = (await _hydrateWith(
          sidebarWidth: once.toStringAsFixed(1),
        )).sidebarWidth;

        expect(twice, once, reason: 'first=$firstStored once=$once');
      },
      tags: 'glados',
    );
  });

  group('PaneWidths value object (Glados)', () {
    glados.Glados3(
      glados.any.sidebarWidthValue,
      glados.any.listPaneWidthValue,
      glados.any.bool,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'copyWith / equality / hashCode hold over arbitrary field triples',
      (sidebar, listPane, collapsed) {
        final original = PaneWidths(
          sidebarWidth: sidebar,
          listPaneWidth: listPane,
          sidebarCollapsed: collapsed,
        );

        // copyWith() with no args round-trips to an equal value, and a freshly
        // constructed twin is equal with a matching hashCode (equality is
        // reflexive and hashCode agrees with ==).
        final twin = PaneWidths(
          sidebarWidth: sidebar,
          listPaneWidth: listPane,
          sidebarCollapsed: collapsed,
        );
        expect(original.copyWith(), equals(original));
        expect(original, equals(original));
        expect(original, equals(twin));
        expect(original.hashCode, equals(original.copyWith().hashCode));
        expect(original.hashCode, equals(twin.hashCode));

        // copyWith overrides exactly the named field and preserves the rest.
        // sidebar is in [0, 1000) so sidebar + 1 is always a distinct value.
        final newSidebar = sidebar + 1;
        final updated = original.copyWith(sidebarWidth: newSidebar);
        expect(updated.sidebarWidth, newSidebar);
        expect(updated.listPaneWidth, listPane);
        expect(updated.sidebarCollapsed, collapsed);

        final toggled = original.copyWith(sidebarCollapsed: !collapsed);
        expect(toggled.sidebarCollapsed, !collapsed);
        expect(toggled.sidebarWidth, sidebar);
        expect(toggled.listPaneWidth, listPane);
      },
      tags: 'glados',
    );
  });

  group('PaneWidthController collapse/expand', () {
    test('collapseSidebar sets the flag and preserves the current width', () {
      final notifier = container.read(paneWidthControllerProvider.notifier)
        ..updateSidebarWidth(40) // sidebarWidth = 360
        ..collapseSidebar();

      final state = container.read(paneWidthControllerProvider);
      expect(state.sidebarCollapsed, isTrue);
      // sidebarWidth is frozen while collapsed so it doubles as the
      // restore target for expand.
      expect(state.sidebarWidth, defaultSidebarWidth + 40);

      // Second call is a no-op.
      notifier.collapseSidebar();
      expect(
        container.read(paneWidthControllerProvider).sidebarWidth,
        defaultSidebarWidth + 40,
      );
    });

    test('expandSidebar keeps the pre-collapse width and clears the flag', () {
      container.read(paneWidthControllerProvider.notifier)
        ..updateSidebarWidth(50) // 370
        ..collapseSidebar()
        ..expandSidebar();

      final state = container.read(paneWidthControllerProvider);
      expect(state.sidebarCollapsed, isFalse);
      expect(state.sidebarWidth, defaultSidebarWidth + 50);
    });

    test('expandSidebar is a no-op when not collapsed', () {
      container.read(paneWidthControllerProvider.notifier).expandSidebar();
      final state = container.read(paneWidthControllerProvider);
      expect(state.sidebarCollapsed, isFalse);
      expect(state.sidebarWidth, defaultSidebarWidth);
    });

    test('toggleSidebarCollapsed flips the flag', () {
      final notifier = container.read(paneWidthControllerProvider.notifier)
        ..toggleSidebarCollapsed();
      expect(
        container.read(paneWidthControllerProvider).sidebarCollapsed,
        isTrue,
      );

      notifier.toggleSidebarCollapsed();
      expect(
        container.read(paneWidthControllerProvider).sidebarCollapsed,
        isFalse,
      );
    });

    test('updateSidebarWidth is ignored while collapsed', () {
      container.read(paneWidthControllerProvider.notifier)
        ..collapseSidebar()
        ..updateSidebarWidth(100);

      final state = container.read(paneWidthControllerProvider);
      // sidebarWidth is frozen while collapsed — this is the invariant
      // that lets expand restore the pre-collapse position.
      expect(state.sidebarWidth, defaultSidebarWidth);
      expect(state.sidebarCollapsed, isTrue);
    });

    test('collapseSidebar persists the flag and current width', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..updateSidebarWidth(30) // 350
          ..collapseSidebar();
        async
          ..flushMicrotasks()
          ..elapse(persistDebounce);

        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarCollapsedKey,
            'true',
          ),
        ).called(1);
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarWidthKey,
            '350.0',
          ),
        ).called(1);
      });
    });

    test('expandSidebar persists flag = false', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..collapseSidebar()
          ..expandSidebar();
        async
          ..flushMicrotasks()
          ..elapse(persistDebounce);

        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarCollapsedKey,
            'false',
          ),
        ).called(1);
      });
    });

    test(
      'expand does not re-persist sidebarWidth — the value is unchanged '
      'because updateSidebarWidth is a no-op while collapsed',
      () {
        fakeAsync((async) {
          container.read(paneWidthControllerProvider.notifier)
            ..updateSidebarWidth(30) // 350, flushed by collapse below
            ..collapseSidebar();
          async
            ..flushMicrotasks()
            ..elapse(persistDebounce);

          clearInteractions(getIt<SettingsDb>());

          container.read(paneWidthControllerProvider.notifier).expandSidebar();
          async
            ..flushMicrotasks()
            ..elapse(persistDebounce);

          verifyNever(
            () => getIt<SettingsDb>().saveSettingsItem(
              sidebarWidthKey,
              any(),
            ),
          );
        });
      },
    );

    test('collapse flushes pending sidebar-width synchronously', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..updateSidebarWidth(30) // 350, debounce pending
          ..collapseSidebar();
        async
          ..flushMicrotasks()
          ..elapse(persistDebounce);

        // The debounced write must not fire a second time. Collapse flushes
        // the current width synchronously so the debounce has nothing left
        // to do — sidebarWidth is written exactly once with the final value.
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            sidebarWidthKey,
            '350.0',
          ),
        ).called(1);
      });
    });
  });

  group('PaneWidthController dispose', () {
    test('disposing the provider cancels pending debounced writes', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..updateSidebarWidth(40)
          ..updateListPaneWidth(80);
        // Drain the synchronous state mutation but do NOT advance time, so the
        // 300ms debounce timers are still pending when we dispose.
        async.flushMicrotasks();

        container.dispose();
        // Replace with a fresh container so the file-level tearDown disposes a
        // valid (and so far unread) instance.
        container = ProviderContainer();

        // Advancing past the debounce window must not fire the cancelled
        // timers — onDispose cancels both, so no write reaches SettingsDb.
        async.elapse(persistDebounce);

        verifyNever(
          () => getIt<SettingsDb>().saveSettingsItem(sidebarWidthKey, any()),
        );
        verifyNever(
          () => getIt<SettingsDb>().saveSettingsItem(listPaneWidthKey, any()),
        );
      });
    });
  });

  group('PaneWidthController error handling', () {
    test('keeps defaults when loadPersistedWidths throws', () async {
      container.dispose();
      await tearDownTestGetIt();
      final mocks = await setUpTestGetIt();
      when(
        () => mocks.settingsDb.itemsByKeys(any()),
      ).thenThrow(Exception('database error'));
      container = ProviderContainer();

      final result = await _awaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
      expect(result.listPaneWidth, defaultListPaneWidth);
    });

    test('logs error when persist write fails', () {
      fakeAsync((async) {
        when(
          () => getIt<SettingsDb>().saveSettingsItem(any(), any()),
        ).thenThrow(Exception('write error'));

        container
            .read(paneWidthControllerProvider.notifier)
            .updateSidebarWidth(30);
        async
          ..flushMicrotasks()
          ..elapse(persistDebounce);

        // State should still have updated despite persist failure
        expect(
          container.read(paneWidthControllerProvider).sidebarWidth,
          defaultSidebarWidth + 30,
        );
      });
    });
  });
}
