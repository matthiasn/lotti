import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';
import 'pane_width_controller_test_helpers.dart';

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
      container = await hCreateContainerWithPersistedWidths(
        sidebarWidth: 'NaN',
        listPaneWidth: '450.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
      expect(result.listPaneWidth, 450.0);
    });

    test('rejects Infinity persisted list pane width', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarWidth: '280.0',
        listPaneWidth: 'Infinity',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarWidth, 280.0);
      expect(result.listPaneWidth, defaultListPaneWidth);
    });

    test('rejects -Infinity persisted width', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarWidth: '-Infinity',
      );

      final result = await hAwaitHydration(container);
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

        final result = await hHydrateWith(sidebarWidth: stored);

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

        final result = await hHydrateWith(listPaneWidth: stored);

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

        final result = await hHydrateWith(
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
        final once = (await hHydrateWith(
          sidebarWidth: firstStored,
        )).sidebarWidth;

        // Feed the already-clamped result back in; a second pass must not move
        // it (it is already inside [min, max] and round-trips cleanly).
        final twice = (await hHydrateWith(
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

      final result = await hAwaitHydration(container);
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
