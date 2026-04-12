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
