import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      container = await hCreateContainerWithPersistedWidths(
        sidebarWidth: '280.0',
        listPaneWidth: '450.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarWidth, 280.0);
      expect(result.listPaneWidth, 450.0);
    });

    test('clamps persisted sidebar width below minimum', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarWidth: '50.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarWidth, minSidebarWidth);
    });

    test('clamps persisted sidebar width above maximum', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarWidth: '999.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarWidth, maxSidebarWidth);
    });

    test('clamps persisted list pane width below minimum', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        listPaneWidth: '50.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.listPaneWidth, minListPaneWidth);
    });

    test('clamps persisted list pane width above maximum', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        listPaneWidth: '2000.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.listPaneWidth, maxListPaneWidth);
    });

    test('handles non-numeric persisted values gracefully', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarWidth: 'invalid',
        listPaneWidth: 'abc',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
      expect(result.listPaneWidth, defaultListPaneWidth);
    });

    test('handles null persisted values gracefully', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths();

      final result = await hAwaitHydration(container);
      expect(result.sidebarWidth, defaultSidebarWidth);
      expect(result.listPaneWidth, defaultListPaneWidth);
      expect(result.sidebarCollapsed, isFalse);
    });

    test('loads persisted collapse flag', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarCollapsed: 'true',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarCollapsed, isTrue);
    });

    test(
      'loads the persisted sidebarWidth while collapsed so expand restores '
      'the pre-collapse position',
      () async {
        container.dispose();
        container = await hCreateContainerWithPersistedWidths(
          sidebarCollapsed: 'true',
          sidebarWidth: '260.0',
        );

        final result = await hAwaitHydration(container);
        expect(result.sidebarCollapsed, isTrue);
        expect(result.sidebarWidth, 260.0);
      },
    );

    test('treats any value other than "true" as not collapsed', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarCollapsed: 'nope',
      );

      final result = await hAwaitHydration(container);
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
}
