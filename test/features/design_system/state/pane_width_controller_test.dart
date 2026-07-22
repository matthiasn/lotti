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
        journalListPaneWidthKey: null,
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
      expect(widths.journalListPaneWidth, defaultJournalListPaneWidth);
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

    test('copyWith updates journal list pane width independently', () {
      const widths = PaneWidths();
      final updated = widths.copyWith(journalListPaneWidth: 520);
      expect(updated.journalListPaneWidth, 520);
      expect(updated.listPaneWidth, defaultListPaneWidth);
      expect(updated.sidebarWidth, defaultSidebarWidth);
    });

    test('equality compares all field values', () {
      const a = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      const b = PaneWidths(sidebarWidth: 300, listPaneWidth: 500);
      const c = PaneWidths(sidebarWidth: 300, listPaneWidth: 600);
      const d = PaneWidths(sidebarWidth: 300, sidebarCollapsed: true);
      const e = PaneWidths(
        sidebarWidth: 300,
        listPaneWidth: 500,
        journalListPaneWidth: 350,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
      expect(a, isNot(equals(e)));
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
            '286.0',
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
            '316.0',
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
            '492.0',
          ),
        ).called(1);
      });
    });
  });

  group('PaneWidthController journal list pane width', () {
    test('hydrates the persisted journal width', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        journalListPaneWidth: '420.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.journalListPaneWidth, 420.0);
    });

    test('clamps persisted journal width into its window', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        journalListPaneWidth: '50.0',
      );
      expect(
        (await hAwaitHydration(container)).journalListPaneWidth,
        minJournalListPaneWidth,
      );

      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        journalListPaneWidth: '2000.0',
      );
      expect(
        (await hAwaitHydration(container)).journalListPaneWidth,
        maxJournalListPaneWidth,
      );
    });

    test('updateJournalListPaneWidth applies delta and clamps', () {
      final notifier = container.read(paneWidthControllerProvider.notifier)
        ..updateJournalListPaneWidth(60);
      expect(
        container.read(paneWidthControllerProvider).journalListPaneWidth,
        defaultJournalListPaneWidth + 60,
      );

      notifier.updateJournalListPaneWidth(-2000);
      expect(
        container.read(paneWidthControllerProvider).journalListPaneWidth,
        minJournalListPaneWidth,
      );

      notifier.updateJournalListPaneWidth(5000);
      expect(
        container.read(paneWidthControllerProvider).journalListPaneWidth,
        maxJournalListPaneWidth,
      );
    });

    test('resizing the journal pane leaves the shared list pane alone', () {
      container
          .read(paneWidthControllerProvider.notifier)
          .updateJournalListPaneWidth(80);
      final state = container.read(paneWidthControllerProvider);
      expect(state.listPaneWidth, defaultListPaneWidth);
      expect(state.sidebarWidth, defaultSidebarWidth);
    });

    test('persists after debounce, coalescing rapid drags', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..updateJournalListPaneWidth(10)
          ..updateJournalListPaneWidth(20)
          ..updateJournalListPaneWidth(30);
        async.flushMicrotasks();

        verifyNever(
          () => getIt<SettingsDb>().saveSettingsItem(
            journalListPaneWidthKey,
            any(),
          ),
        );

        async.elapse(persistDebounce);

        // 460 + 10 + 20 + 30 — only the final accumulated value is written.
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            journalListPaneWidthKey,
            '520.0',
          ),
        ).called(1);
      });
    });
  });

  group('PaneWidthController resetToDefaults', () {
    test('resets all widths to defaults', () {
      container.read(paneWidthControllerProvider.notifier)
        ..updateSidebarWidth(50)
        ..updateListPaneWidth(100)
        ..updateJournalListPaneWidth(80)
        ..resetToDefaults();
      final state = container.read(paneWidthControllerProvider);
      expect(state.sidebarWidth, defaultSidebarWidth);
      expect(state.listPaneWidth, defaultListPaneWidth);
      expect(state.journalListPaneWidth, defaultJournalListPaneWidth);
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
          '256.0',
        ),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          listPaneWidthKey,
          '432.0',
        ),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          journalListPaneWidthKey,
          '460.0',
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
            '256.0',
          ),
        ).called(1);
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            listPaneWidthKey,
            '432.0',
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

  group('scaledPaneWidth', () {
    test('returns width unchanged at or below the reference screen width', () {
      expect(
        scaledPaneWidth(
          width: defaultSidebarWidth,
          flatDefault: defaultSidebarWidth,
          minValue: minSidebarWidth,
          maxValue: maxSidebarWidth,
          screenWidth: kPaneWidthReferenceScreenWidth,
        ),
        defaultSidebarWidth,
      );
      expect(
        scaledPaneWidth(
          width: defaultSidebarWidth,
          flatDefault: defaultSidebarWidth,
          minValue: minSidebarWidth,
          maxValue: maxSidebarWidth,
          screenWidth: 1280,
        ),
        defaultSidebarWidth,
      );
    });

    test(
      'scales proportionally with screen width once above the reference, '
      'when width still equals the flat default',
      () {
        final scaled = scaledPaneWidth(
          width: defaultSidebarWidth,
          flatDefault: defaultSidebarWidth,
          minValue: minSidebarWidth,
          maxValue: maxSidebarWidth,
          screenWidth: 1920,
        );
        expect(
          scaled,
          closeTo(
            defaultSidebarWidth * 1920 / kPaneWidthReferenceScreenWidth,
            0.001,
          ),
        );
        expect(scaled, greaterThan(defaultSidebarWidth));
      },
    );

    test('clamps the scaled result to maxValue on very large screens', () {
      final scaled = scaledPaneWidth(
        width: defaultSidebarWidth,
        flatDefault: defaultSidebarWidth,
        minValue: minSidebarWidth,
        maxValue: maxSidebarWidth,
        screenWidth: 4000,
      );
      expect(scaled, maxSidebarWidth);
    });

    test(
      'never scales once the width no longer equals the flat default — '
      'a user-adjusted or already-persisted width is always honored '
      'verbatim, regardless of screen size',
      () {
        const userWidth = 275.0;
        expect(
          scaledPaneWidth(
            width: userWidth,
            flatDefault: defaultSidebarWidth,
            minValue: minSidebarWidth,
            maxValue: maxSidebarWidth,
            screenWidth: 4000,
          ),
          userWidth,
        );
      },
    );

    test('applies the same rules to the list pane constants', () {
      final scaled = scaledPaneWidth(
        width: defaultListPaneWidth,
        flatDefault: defaultListPaneWidth,
        minValue: minListPaneWidth,
        maxValue: maxListPaneWidth,
        screenWidth: 1920,
      );
      expect(scaled, greaterThan(defaultListPaneWidth));
      expect(scaled, lessThanOrEqualTo(maxListPaneWidth));
    });
  });

  group('resolvedPaneWidth', () {
    test(
      'below the reference screen width, onDrag forwards the raw delta '
      'unchanged — displayed width equals the stored width, so no '
      'adjustment is needed',
      () {
        double? forwarded;
        final resolved = resolvedPaneWidth(
          storedWidth: defaultSidebarWidth,
          flatDefault: defaultSidebarWidth,
          minValue: minSidebarWidth,
          maxValue: maxSidebarWidth,
          screenWidth: 1280,
          onDelta: (delta) => forwarded = delta,
        );

        expect(resolved.width, defaultSidebarWidth);
        resolved.onDrag(12);
        expect(forwarded, 12);
      },
    );

    test(
      'above the reference screen width, onDrag adjusts the raw delta by '
      '(displayed - stored) so the divider never desyncs from the pointer '
      'on the first drag frame after large-screen scaling',
      () {
        double? forwarded;
        final resolved = resolvedPaneWidth(
          storedWidth: defaultSidebarWidth,
          flatDefault: defaultSidebarWidth,
          minValue: minSidebarWidth,
          maxValue: maxSidebarWidth,
          screenWidth: 1920,
          onDelta: (delta) => forwarded = delta,
        );

        expect(resolved.width, greaterThan(defaultSidebarWidth));
        resolved.onDrag(10);
        expect(
          forwarded,
          closeTo(resolved.width + 10 - defaultSidebarWidth, 0.001),
        );
      },
    );

    test(
      'once the stored width has been user-adjusted, onDrag forwards the '
      'raw delta unchanged — scaledPaneWidth no longer scales, so displayed '
      'and stored are identical regardless of screen size',
      () {
        const userWidth = 275.0;
        double? forwarded;
        final resolved = resolvedPaneWidth(
          storedWidth: userWidth,
          flatDefault: defaultSidebarWidth,
          minValue: minSidebarWidth,
          maxValue: maxSidebarWidth,
          screenWidth: 4000,
          onDelta: (delta) => forwarded = delta,
        );

        expect(resolved.width, userWidth);
        resolved.onDrag(-5);
        expect(forwarded, -5);
      },
    );
  });
}
