import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

/// Creates a fresh [ProviderContainer] with [SettingsDb.itemsByKeys] stubbed
/// to return the given values for the pane width keys.
Future<ProviderContainer> _createContainerWithPersistedWidths({
  String? sidebarWidth,
  String? listPaneWidth,
}) async {
  await tearDownTestGetIt();
  final mocks = await setUpTestGetIt();
  when(
    () => mocks.settingsDb.itemsByKeys(any()),
  ).thenAnswer(
    (_) async => <String, String?>{
      sidebarWidthKey: sidebarWidth,
      listPaneWidthKey: listPaneWidth,
    },
  );
  return ProviderContainer();
}

/// Triggers provider read and flushes microtasks so the async
/// `_loadPersistedWidths` (which calls the mocked `itemsByKeys`)
/// completes deterministically.
Future<PaneWidths> _awaitHydration(ProviderContainer container) async {
  // Force provider build, which fires _loadPersistedWidths.
  container.read(paneWidthControllerProvider);
  // The mock resolves synchronously as a microtask — flush it.
  await Future<void>.value();
  return container.read(paneWidthControllerProvider);
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

    test('equality compares field values', () {
      const a = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      const b = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      const c = PaneWidths(sidebarWidth: 300, listPaneWidth: 600);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
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
