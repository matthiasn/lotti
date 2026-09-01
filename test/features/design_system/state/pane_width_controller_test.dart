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
        listPaneCollapsedKey: null,
        dayViewPanelWidthKey: null,
        dayViewPanelHiddenKey: null,
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
      expect(widths.listPaneCollapsed, isFalse);
      expect(widths.dayViewPanelWidth, defaultDayViewPanelWidth);
      // The day-view column is opt-in: hidden until the user shows it.
      expect(widths.dayViewPanelHidden, isTrue);
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

    test('copyWith updates list pane collapse flag', () {
      const widths = PaneWidths();
      final updated = widths.copyWith(listPaneCollapsed: true);
      expect(updated.listPaneCollapsed, isTrue);
      expect(updated.listPaneWidth, defaultListPaneWidth);
    });

    test('copyWith updates journal list pane width independently', () {
      const widths = PaneWidths();
      final updated = widths.copyWith(journalListPaneWidth: 520);
      expect(updated.journalListPaneWidth, 520);
      expect(updated.listPaneWidth, defaultListPaneWidth);
      expect(updated.sidebarWidth, defaultSidebarWidth);
    });

    test('copyWith updates day view panel width and hidden flag', () {
      const widths = PaneWidths();
      final updated = widths.copyWith(
        dayViewPanelWidth: 440,
        dayViewPanelHidden: true,
      );
      expect(updated.dayViewPanelWidth, 440);
      expect(updated.dayViewPanelHidden, isTrue);
      expect(updated.sidebarWidth, defaultSidebarWidth);
      expect(updated.listPaneWidth, defaultListPaneWidth);
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
      const f = PaneWidths(listPaneCollapsed: true);
      const g = PaneWidths(
        sidebarWidth: 300,
        listPaneWidth: 500,
        dayViewPanelWidth: 420,
      );
      // Off the (hidden) default so the field actually differs.
      const h = PaneWidths(
        sidebarWidth: 300,
        listPaneWidth: 500,
        dayViewPanelHidden: false,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
      expect(a, isNot(equals(e)));
      expect(a, isNot(equals(f)));
      expect(a, isNot(equals(g)));
      expect(a, isNot(equals(h)));
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
      expect(result.listPaneCollapsed, isFalse);
    });

    test('loads persisted collapse flag', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        sidebarCollapsed: 'true',
      );

      final result = await hAwaitHydration(container);
      expect(result.sidebarCollapsed, isTrue);
    });

    test('loads persisted list pane collapse flag and restore width', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        listPaneCollapsed: 'true',
        listPaneWidth: '510.0',
      );

      final result = await hAwaitHydration(container);
      expect(result.listPaneCollapsed, isTrue);
      expect(result.listPaneWidth, 510);
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

    test('ignores resize input while collapsed and restores prior width', () {
      final notifier = container.read(paneWidthControllerProvider.notifier)
        ..updateListPaneWidth(60)
        ..collapseListPane()
        ..updateListPaneWidth(120);

      var state = container.read(paneWidthControllerProvider);
      expect(state.listPaneCollapsed, isTrue);
      expect(state.listPaneWidth, defaultListPaneWidth + 60);

      notifier.expandListPane();
      state = container.read(paneWidthControllerProvider);
      expect(state.listPaneCollapsed, isFalse);
      expect(state.listPaneWidth, defaultListPaneWidth + 60);
    });

    test('allows a forced-visible collapsed pane to resize', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..collapseListPane()
          ..updateListPaneWidth(40, allowWhileCollapsed: true);

        final state = container.read(paneWidthControllerProvider);
        expect(state.listPaneCollapsed, isTrue);
        expect(state.listPaneWidth, defaultListPaneWidth + 40);

        async.elapse(persistDebounce);
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            listPaneWidthKey,
            '${defaultListPaneWidth + 40}',
          ),
        ).called(1);
      });
    });

    test('persists focus mode immediately and toggles idempotently', () {
      container.read(paneWidthControllerProvider.notifier)
        ..updateListPaneWidth(30)
        ..collapseListPane()
        ..collapseListPane();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          listPaneWidthKey,
          '${defaultListPaneWidth + 30}',
        ),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          listPaneCollapsedKey,
          'true',
        ),
      ).called(1);

      container.read(paneWidthControllerProvider.notifier)
        ..toggleListPaneCollapsed()
        ..expandListPane();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          listPaneCollapsedKey,
          'false',
        ),
      ).called(1);
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

  group('PaneWidthController day view panel', () {
    test('hydrates the persisted width and hidden flag', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        dayViewPanelWidth: '450.0',
        dayViewPanelHidden: 'true',
      );

      final result = await hAwaitHydration(container);
      expect(result.dayViewPanelWidth, 450.0);
      expect(result.dayViewPanelHidden, isTrue);
    });

    test('clamps the persisted width into its window', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        dayViewPanelWidth: '50.0',
      );
      expect(
        (await hAwaitHydration(container)).dayViewPanelWidth,
        minDayViewPanelWidth,
      );

      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        dayViewPanelWidth: '2000.0',
      );
      expect(
        (await hAwaitHydration(container)).dayViewPanelWidth,
        maxDayViewPanelWidth,
      );
    });

    test('defaults to hidden when nothing is persisted', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths();

      final result = await hAwaitHydration(container);
      expect(result.dayViewPanelHidden, isTrue);
      expect(result.dayViewPanelWidth, defaultDayViewPanelWidth);
    });

    test(
      'stays visible once the user has shown it (persisted false)',
      () async {
        container.dispose();
        container = await hCreateContainerWithPersistedWidths(
          dayViewPanelHidden: 'false',
        );

        expect((await hAwaitHydration(container)).dayViewPanelHidden, isFalse);
      },
    );

    test('an unparseable persisted flag falls back to hidden', () async {
      container.dispose();
      container = await hCreateContainerWithPersistedWidths(
        dayViewPanelHidden: 'maybe',
      );

      expect((await hAwaitHydration(container)).dayViewPanelHidden, isTrue);
    });

    test('updateDayViewPanelWidth applies delta and clamps', () {
      // Shown first: the column starts hidden, where drags are refused.
      final notifier = container.read(paneWidthControllerProvider.notifier)
        ..showDayViewPanel()
        ..updateDayViewPanelWidth(60);
      expect(
        container.read(paneWidthControllerProvider).dayViewPanelWidth,
        defaultDayViewPanelWidth + 60,
      );

      notifier.updateDayViewPanelWidth(-2000);
      expect(
        container.read(paneWidthControllerProvider).dayViewPanelWidth,
        minDayViewPanelWidth,
      );

      notifier.updateDayViewPanelWidth(5000);
      expect(
        container.read(paneWidthControllerProvider).dayViewPanelWidth,
        maxDayViewPanelWidth,
      );
    });

    test('resizing the day view panel leaves the other panes alone', () {
      container.read(paneWidthControllerProvider.notifier)
        ..showDayViewPanel()
        ..updateDayViewPanelWidth(80);
      final state = container.read(paneWidthControllerProvider);
      expect(state.dayViewPanelWidth, defaultDayViewPanelWidth + 80);
      expect(state.sidebarWidth, defaultSidebarWidth);
      expect(state.listPaneWidth, defaultListPaneWidth);
      expect(state.journalListPaneWidth, defaultJournalListPaneWidth);
    });

    test('persists after debounce, coalescing rapid drags', () {
      fakeAsync((async) {
        container.read(paneWidthControllerProvider.notifier)
          ..showDayViewPanel()
          ..updateDayViewPanelWidth(10)
          ..updateDayViewPanelWidth(20)
          ..updateDayViewPanelWidth(30);
        async.flushMicrotasks();

        verifyNever(
          () => getIt<SettingsDb>().saveSettingsItem(
            dayViewPanelWidthKey,
            any(),
          ),
        );

        async.elapse(persistDebounce);

        // 380 + 10 + 20 + 30 — only the final accumulated value is written.
        verify(
          () => getIt<SettingsDb>().saveSettingsItem(
            dayViewPanelWidthKey,
            '440.0',
          ),
        ).called(1);
      });
    });

    test('ignores resize input while hidden and restores prior width', () {
      final notifier = container.read(paneWidthControllerProvider.notifier)
        // A drag against the hidden default is refused outright.
        ..updateDayViewPanelWidth(45);
      expect(
        container.read(paneWidthControllerProvider).dayViewPanelWidth,
        defaultDayViewPanelWidth,
      );

      notifier
        ..showDayViewPanel()
        ..updateDayViewPanelWidth(60)
        ..hideDayViewPanel()
        ..updateDayViewPanelWidth(120);

      var state = container.read(paneWidthControllerProvider);
      expect(state.dayViewPanelHidden, isTrue);
      expect(state.dayViewPanelWidth, defaultDayViewPanelWidth + 60);

      notifier.showDayViewPanel();
      state = container.read(paneWidthControllerProvider);
      expect(state.dayViewPanelHidden, isFalse);
      expect(state.dayViewPanelWidth, defaultDayViewPanelWidth + 60);
    });

    test('persists hide immediately and toggles idempotently', () {
      container.read(paneWidthControllerProvider.notifier).showDayViewPanel();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          dayViewPanelHiddenKey,
          'false',
        ),
      ).called(1);

      container.read(paneWidthControllerProvider.notifier)
        ..updateDayViewPanelWidth(30)
        ..hideDayViewPanel()
        ..hideDayViewPanel();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          dayViewPanelWidthKey,
          '${defaultDayViewPanelWidth + 30}',
        ),
      ).called(1);
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          dayViewPanelHiddenKey,
          'true',
        ),
      ).called(1);

      container.read(paneWidthControllerProvider.notifier)
        ..toggleDayViewPanelHidden()
        ..showDayViewPanel();
      verify(
        () => getIt<SettingsDb>().saveSettingsItem(
          dayViewPanelHiddenKey,
          'false',
        ),
      ).called(1);
    });

    test('toggleDayViewPanelHidden flips hidden -> visible -> hidden', () {
      final notifier = container.read(paneWidthControllerProvider.notifier)
        ..toggleDayViewPanelHidden();
      expect(
        container.read(paneWidthControllerProvider).dayViewPanelHidden,
        isFalse,
      );
      notifier.toggleDayViewPanelHidden();
      expect(
        container.read(paneWidthControllerProvider).dayViewPanelHidden,
        isTrue,
      );
    });
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
