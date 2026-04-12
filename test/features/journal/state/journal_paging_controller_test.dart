// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_paging_controller.dart';

JournalEntity _makeEntry(String id) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024, 3, 15),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
    ),
    entryText: const EntryText(plainText: 'test', markdown: 'test'),
  );
}

JournalPagingController _createController() {
  return JournalPagingController(
    getNextPageKey: (state) => null,
    fetchPage: (key) async => <JournalEntity>[],
  );
}

void main() {
  group('JournalPagingController', () {
    late JournalPagingController controller;

    setUp(() {
      controller = _createController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('hasVisibleItems', () {
      test('returns false for empty controller with no pages', () {
        expect(controller.hasVisibleItems, isFalse);
      });

      test('returns false when pages exist but are all empty', () {
        controller.replacePages(
          [<JournalEntity>[], <JournalEntity>[]],
          keys: [0, 1],
          hasNextPage: false,
        );

        expect(controller.hasVisibleItems, isFalse);
      });

      test('returns true when at least one page has items', () {
        final entry = _makeEntry('entry-1');
        controller.replacePages(
          [
            [entry],
          ],
          keys: [0],
          hasNextPage: false,
        );

        expect(controller.hasVisibleItems, isTrue);
      });

      test('returns true when first page is empty but second has items', () {
        final entry = _makeEntry('entry-2');
        controller.replacePages(
          [
            <JournalEntity>[],
            [entry],
          ],
          keys: [0, 1],
          hasNextPage: false,
        );

        expect(controller.hasVisibleItems, isTrue);
      });
    });

    group('startRetainedRefresh', () {
      test('sets loading state to true and clears error', () {
        final token = Object();

        controller.startRetainedRefresh(token);

        expect(controller.value.isLoading, isTrue);
        expect(controller.value.error, isNull);
      });

      test('sets operation to the provided refresh token', () {
        final token = Object();

        controller.startRetainedRefresh(token);

        expect(controller.isRetainedRefresh(token), isTrue);
      });
    });

    group('isRetainedRefresh', () {
      test('returns true for the matching token', () {
        final token = Object();
        controller.startRetainedRefresh(token);

        expect(controller.isRetainedRefresh(token), isTrue);
      });

      test('returns false for a different token', () {
        final token = Object();
        final otherToken = Object();
        controller.startRetainedRefresh(token);

        expect(controller.isRetainedRefresh(otherToken), isFalse);
      });

      test('returns false when no refresh is in progress', () {
        final token = Object();

        expect(controller.isRetainedRefresh(token), isFalse);
      });
    });

    group('replacePages', () {
      test('updates pages with provided data', () {
        final entry1 = _makeEntry('entry-a');
        final entry2 = _makeEntry('entry-b');

        controller.replacePages(
          [
            [entry1],
            [entry2],
          ],
          keys: [0, 1],
          hasNextPage: true,
        );

        expect(controller.value.pages, hasLength(2));
        expect(controller.value.pages![0], contains(entry1));
        expect(controller.value.pages![1], contains(entry2));
      });

      test('updates keys to provided values', () {
        final entry = _makeEntry('entry-c');

        controller.replacePages(
          [
            [entry],
          ],
          keys: [42],
          hasNextPage: false,
        );

        expect(controller.value.keys, equals([42]));
      });

      test('sets hasNextPage flag correctly', () {
        controller.replacePages(
          [<JournalEntity>[]],
          keys: [0],
          hasNextPage: true,
        );
        expect(controller.value.hasNextPage, isTrue);

        controller.replacePages(
          [<JournalEntity>[]],
          keys: [0],
          hasNextPage: false,
        );
        expect(controller.value.hasNextPage, isFalse);
      });

      test('clears the operation token after replacing pages', () {
        final token = Object();
        controller.startRetainedRefresh(token);
        expect(controller.isRetainedRefresh(token), isTrue);

        controller.replacePages(
          [<JournalEntity>[]],
          keys: [0],
          hasNextPage: false,
        );

        expect(controller.isRetainedRefresh(token), isFalse);
      });
    });

    group('finishRetainedRefreshWithError', () {
      test('sets error when token matches the current operation', () {
        final token = Object();
        final error = Exception('network failure');

        controller.startRetainedRefresh(token);
        controller.finishRetainedRefreshWithError(
          error,
          refreshToken: token,
        );

        expect(controller.value.error, equals(error));
        expect(controller.value.isLoading, isFalse);
      });

      test('clears operation token after setting error', () {
        final token = Object();

        controller.startRetainedRefresh(token);
        controller.finishRetainedRefreshWithError(
          Exception('fail'),
          refreshToken: token,
        );

        expect(controller.isRetainedRefresh(token), isFalse);
      });

      test('ignores error when token does not match', () {
        final token = Object();
        final staleToken = Object();
        final error = Exception('stale error');

        controller.startRetainedRefresh(token);
        controller.finishRetainedRefreshWithError(
          error,
          refreshToken: staleToken,
        );

        // Error should not be set because the token did not match
        expect(controller.value.error, isNull);
        // Loading state should remain unchanged (still loading from
        // startRetainedRefresh)
        expect(controller.value.isLoading, isTrue);
        // The current operation should still be the original token
        expect(controller.isRetainedRefresh(token), isTrue);
      });

      test('ignores error when no refresh is in progress', () {
        final token = Object();
        final error = Exception('unexpected');

        controller.finishRetainedRefreshWithError(
          error,
          refreshToken: token,
        );

        expect(controller.value.error, isNull);
      });
    });

    group('refreshLoadedPages', () {
      test(
        'falls back to refresh+fetchNextPage when no pages loaded',
        () async {
          // Controller starts with no pages — refreshLoadedPages should call
          // refresh() and fetchNextPage() and return.
          final ctrl = JournalPagingController(
            getNextPageKey: (state) => null,
            fetchPage: (key) async => <JournalEntity>[],
          );

          await ctrl.refreshLoadedPages(
            runQuery: (pageKey, {setPostFilterNextRawOffset}) async {
              fail('runQuery should not be called for empty pages fallback');
            },
            requiresSequential: false,
            pageSize: 10,
            isMounted: () => true,
            onPostFilterOffset: (_) {},
            onLeadingItems: (_) {},
          );

          // fetchPage is invoked asynchronously by the paging framework after
          // fetchNextPage(), so we just verify the method didn't throw and
          // completed normally (the fallback path was taken).
          // The controller should have called refresh() which resets state.
          expect(ctrl.value.pages, isNull);

          ctrl.dispose();
        },
      );

      test(
        'sequential refresh computes next page key from previous page',
        () async {
          // Create enough entries to fill a page (pageSize=2 for this test).
          final entries1 = [_makeEntry('s-1'), _makeEntry('s-2')];
          final entries2 = [_makeEntry('s-3'), _makeEntry('s-4')];

          // Set up controller with 2 pages.
          controller.replacePages(
            [entries1, entries2],
            keys: [0, 2],
            hasNextPage: true,
          );

          final queriedKeys = <int>[];
          await controller.refreshLoadedPages(
            runQuery: (pageKey, {setPostFilterNextRawOffset}) async {
              queriedKeys.add(pageKey);
              // Simulate post-filter offset that differs from item count.
              setPostFilterNextRawOffset?.call(pageKey + 5);
              return [_makeEntry('r-$pageKey-a'), _makeEntry('r-$pageKey-b')];
            },
            requiresSequential: true,
            // pageSize matches returned items so loop doesn't exit early.
            pageSize: 2,
            isMounted: () => true,
            onPostFilterOffset: (_) {},
            onLeadingItems: (_) {},
          );

          // First page starts at 0, second page uses retainedNextRawOffset
          // from page 1 (0 + 5 = 5).
          expect(queriedKeys, [0, 5]);
        },
      );

      test(
        'only refreshes non-empty pages (skips empty pages in keys)',
        () async {
          final entry = _makeEntry('p1');

          // Set up 2 pages where the second is empty.
          controller.replacePages(
            [
              [entry],
              <JournalEntity>[],
            ],
            keys: [0, 10],
            hasNextPage: false,
          );

          // _loadedVisiblePageKeys only returns keys for non-empty pages.
          final queriedKeys = <int>[];
          await controller.refreshLoadedPages(
            runQuery: (pageKey, {setPostFilterNextRawOffset}) async {
              queriedKeys.add(pageKey);
              return [_makeEntry('refreshed-$pageKey')];
            },
            requiresSequential: false,
            pageSize: 10,
            isMounted: () => true,
            onPostFilterOffset: (_) {},
            onLeadingItems: (_) {},
          );

          // Only page at key 0 (non-empty) should be queried.
          expect(queriedKeys, [0]);
        },
      );
    });

    group('retained refresh lifecycle', () {
      test('full cycle: start refresh, replace pages, verify clean state', () {
        final token = Object();
        final entry = _makeEntry('lifecycle-entry');

        // Start a retained refresh
        controller.startRetainedRefresh(token);
        expect(controller.value.isLoading, isTrue);
        expect(controller.isRetainedRefresh(token), isTrue);

        // Replace pages (simulating successful data fetch)
        controller.replacePages(
          [
            [entry],
          ],
          keys: [0],
          hasNextPage: false,
        );

        // After replacement: not loading, no operation, has items
        expect(controller.value.isLoading, isFalse);
        expect(controller.isRetainedRefresh(token), isFalse);
        expect(controller.hasVisibleItems, isTrue);
        expect(controller.value.error, isNull);
      });

      test('superseded refresh: new token invalidates old one', () {
        final oldToken = Object();
        final newToken = Object();

        controller.startRetainedRefresh(oldToken);
        expect(controller.isRetainedRefresh(oldToken), isTrue);

        // A new refresh supersedes the old one
        controller.startRetainedRefresh(newToken);
        expect(controller.isRetainedRefresh(oldToken), isFalse);
        expect(controller.isRetainedRefresh(newToken), isTrue);

        // Error for the old token is ignored
        controller.finishRetainedRefreshWithError(
          Exception('old failure'),
          refreshToken: oldToken,
        );
        expect(controller.value.error, isNull);
        expect(controller.value.isLoading, isTrue);

        // Error for the new token is applied
        final newError = Exception('new failure');
        controller.finishRetainedRefreshWithError(
          newError,
          refreshToken: newToken,
        );
        expect(controller.value.error, equals(newError));
        expect(controller.value.isLoading, isFalse);
      });
    });
  });
}
