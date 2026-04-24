import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';

SettingsTreePath _notifierFrom(ProviderContainer c) =>
    c.read(settingsTreePathProvider.notifier);

void main() {
  group('SettingsTreePath — initial state', () {
    test('builds to the empty path', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(settingsTreePathProvider), isEmpty);
    });
  });

  group('SettingsTreePath.onNodeTap — rule 2 (open a branch)', () {
    test('tapping a root branch opens it at depth 0', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('sync', depth: 0, hasChildren: true);
      expect(c.read(settingsTreePathProvider), ['sync']);
    });

    test('opening a sibling of the current open branch replaces it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('sync', depth: 0, hasChildren: true);
      _notifierFrom(c).onNodeTap('advanced', depth: 0, hasChildren: true);
      expect(c.read(settingsTreePathProvider), ['advanced']);
    });

    test('opening at depth 1 preserves the ancestor chain', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c)
        ..onNodeTap('sync', depth: 0, hasChildren: true)
        ..onNodeTap('sync/backfill', depth: 1, hasChildren: true);
      expect(c.read(settingsTreePathProvider), ['sync', 'sync/backfill']);
    });

    test(
      'opening a deeper branch after a leaf selection drops the stale leaf',
      () {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        _notifierFrom(c)
          ..onNodeTap('sync', depth: 0, hasChildren: true)
          ..onNodeTap('sync/backfill', depth: 1, hasChildren: false)
          ..onNodeTap('advanced', depth: 0, hasChildren: true);
        expect(c.read(settingsTreePathProvider), ['advanced']);
      },
    );
  });

  group('SettingsTreePath.onNodeTap — rule 1 (collapse an open branch)', () {
    test('tapping the currently-open branch at its depth collapses it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c)
        ..onNodeTap('sync', depth: 0, hasChildren: true)
        ..onNodeTap('sync', depth: 0, hasChildren: true);
      expect(c.read(settingsTreePathProvider), isEmpty);
    });

    test('collapsing a branch at depth 1 preserves the root selection', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c)
        ..onNodeTap('advanced', depth: 0, hasChildren: true)
        ..onNodeTap('advanced/logging', depth: 1, hasChildren: true)
        ..onNodeTap('advanced/logging', depth: 1, hasChildren: true);
      expect(c.read(settingsTreePathProvider), ['advanced']);
    });
  });

  group('SettingsTreePath.onNodeTap — rule 3 (select a leaf)', () {
    test('selecting a leaf at depth 0 sets a single-segment path', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('categories', depth: 0, hasChildren: false);
      expect(c.read(settingsTreePathProvider), ['categories']);
    });

    test('selecting a leaf under an open branch appends it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c)
        ..onNodeTap('sync', depth: 0, hasChildren: true)
        ..onNodeTap('sync/backfill', depth: 1, hasChildren: false);
      expect(c.read(settingsTreePathProvider), ['sync', 'sync/backfill']);
    });

    test('leaf-under-branch swap replaces only the leaf, not the branch', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c)
        ..onNodeTap('sync', depth: 0, hasChildren: true)
        ..onNodeTap('sync/backfill', depth: 1, hasChildren: false)
        ..onNodeTap('sync/stats', depth: 1, hasChildren: false);
      expect(c.read(settingsTreePathProvider), ['sync', 'sync/stats']);
    });
  });

  group(
    'SettingsTreePath.onNodeTap — rule 4 (already-selected leaf no-op)',
    () {
      test(
        'tapping the selected leaf again leaves state and identity intact',
        () {
          final c = ProviderContainer();
          addTearDown(c.dispose);
          _notifierFrom(
            c,
          ).onNodeTap('categories', depth: 0, hasChildren: false);
          final first = c.read(settingsTreePathProvider);
          _notifierFrom(
            c,
          ).onNodeTap('categories', depth: 0, hasChildren: false);
          final second = c.read(settingsTreePathProvider);
          expect(second, ['categories']);
          // No mutation expected — identity-equal confirms rule 4 short-
          // circuits before reassigning state.
          expect(identical(first, second), isTrue);
        },
      );

      test(
        'tapping a previously-selected leaf under an open branch is a no-op',
        () {
          final c = ProviderContainer();
          addTearDown(c.dispose);
          _notifierFrom(c)
            ..onNodeTap('sync', depth: 0, hasChildren: true)
            ..onNodeTap('sync/backfill', depth: 1, hasChildren: false);
          final first = c.read(settingsTreePathProvider);
          _notifierFrom(
            c,
          ).onNodeTap('sync/backfill', depth: 1, hasChildren: false);
          expect(identical(c.read(settingsTreePathProvider), first), isTrue);
        },
      );
    },
  );

  group('SettingsTreePath.onNodeTap — stale depth handling', () {
    test('clamps a depth beyond state.length to append at the tail', () {
      // A stale `depth` greater than `state.length` must not throw —
      // and it must install the tapped id at the end of the current
      // path, matching "open one level deeper" intent.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(
        c,
      ).onNodeTap('categories', depth: 5, hasChildren: false);
      expect(c.read(settingsTreePathProvider), ['categories']);
    });

    test('clamps a negative depth to the root', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('sync', depth: 0, hasChildren: true);
      _notifierFrom(c).onNodeTap('advanced', depth: -1, hasChildren: true);
      expect(c.read(settingsTreePathProvider), ['advanced']);
    });
  });

  group('SettingsTreePath.truncateTo', () {
    test('clamps a depth greater than path length to no-op', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('sync', depth: 0, hasChildren: true);
      _notifierFrom(c).truncateTo(99);
      expect(c.read(settingsTreePathProvider), ['sync']);
    });

    test('truncate(0) resets to an empty path', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c)
        ..onNodeTap('sync', depth: 0, hasChildren: true)
        ..onNodeTap('sync/backfill', depth: 1, hasChildren: false);
      _notifierFrom(c).truncateTo(0);
      expect(c.read(settingsTreePathProvider), isEmpty);
    });

    test('truncate(1) keeps only the root segment', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c)
        ..onNodeTap('sync', depth: 0, hasChildren: true)
        ..onNodeTap('sync/backfill', depth: 1, hasChildren: false);
      _notifierFrom(c).truncateTo(1);
      expect(c.read(settingsTreePathProvider), ['sync']);
    });

    test('truncate to current depth is a no-op (no state mutation)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('sync', depth: 0, hasChildren: true);
      final first = c.read(settingsTreePathProvider);
      _notifierFrom(c).truncateTo(first.length);
      expect(identical(c.read(settingsTreePathProvider), first), isTrue);
    });

    test('negative depth clamps to 0', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('sync', depth: 0, hasChildren: true);
      _notifierFrom(c).truncateTo(-5);
      expect(c.read(settingsTreePathProvider), isEmpty);
    });
  });

  group('SettingsTreePath.clear', () {
    test('clears a populated path to empty', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).onNodeTap('sync', depth: 0, hasChildren: true);
      _notifierFrom(c).clear();
      expect(c.read(settingsTreePathProvider), isEmpty);
    });

    test('clearing an already-empty path is a no-op (identity preserved)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final first = c.read(settingsTreePathProvider);
      _notifierFrom(c).clear();
      expect(identical(c.read(settingsTreePathProvider), first), isTrue);
    });
  });

  group('SettingsTreePath.syncFromUrl', () {
    test('/settings → empty path', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).syncFromUrl('/settings');
      expect(c.read(settingsTreePathProvider), isEmpty);
    });

    test('/settings/sync/backfill → [sync, sync/backfill]', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).syncFromUrl('/settings/sync/backfill');
      expect(c.read(settingsTreePathProvider), ['sync', 'sync/backfill']);
    });

    test('unknown URL falls back to empty path', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).syncFromUrl('/settings/nonsense/deeper');
      expect(c.read(settingsTreePathProvider), isEmpty);
    });

    test('UUID segment is treated as panel-local', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).syncFromUrl('/settings/categories/abc-123');
      expect(c.read(settingsTreePathProvider), ['categories']);
    });

    test('idempotent: same URL twice does not notify listeners twice', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).syncFromUrl('/settings/advanced/about');
      final first = c.read(settingsTreePathProvider);
      _notifierFrom(c).syncFromUrl('/settings/advanced/about');
      expect(identical(c.read(settingsTreePathProvider), first), isTrue);
    });

    test('changing URL moves to the new tree path', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifierFrom(c).syncFromUrl('/settings/sync/backfill');
      _notifierFrom(c).syncFromUrl('/settings/advanced/logging_domains');
      expect(c.read(settingsTreePathProvider), [
        'advanced',
        'advanced/logging',
      ]);
    });
  });
}
