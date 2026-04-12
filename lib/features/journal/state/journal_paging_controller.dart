import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/services/dev_logger.dart';

/// Callback that runs a paginated query for a given page key.
/// Used by [JournalPagingController.refreshLoadedPages] to re-fetch data.
typedef PageQueryFn =
    Future<List<JournalEntity>> Function(
      int pageKey, {
      void Function(int? nextRawOffset)? setPostFilterNextRawOffset,
    });

/// Custom paging controller for journal/task lists that supports
/// retained refreshes (replacing page content without losing scroll position).
class JournalPagingController extends PagingController<int, JournalEntity> {
  JournalPagingController({
    required super.getNextPageKey,
    required super.fetchPage,
  });

  bool get hasVisibleItems =>
      value.pages?.any((page) => page.isNotEmpty) ?? false;

  void startRetainedRefresh(Object refreshToken) {
    operation = refreshToken;
    value = value.copyWith(
      error: null,
      isLoading: true,
    );
  }

  bool isRetainedRefresh(Object refreshToken) => operation == refreshToken;

  void replacePages(
    List<List<JournalEntity>> pages, {
    required List<int> keys,
    required bool hasNextPage,
  }) {
    value = PagingState<int, JournalEntity>(
      pages: pages,
      keys: keys,
      hasNextPage: hasNextPage,
    );
    operation = null;
  }

  void finishRetainedRefreshWithError(
    Object error, {
    required Object refreshToken,
  }) {
    if (operation != refreshToken) {
      return;
    }

    value = value.copyWith(
      error: error,
      isLoading: false,
    );
    operation = null;
  }

  // ---------------------------------------------------------------
  // Retained refresh orchestration
  // ---------------------------------------------------------------

  /// Re-fetches all currently loaded pages in-place, preserving scroll
  /// position. Falls back to a full refresh when no pages are loaded.
  ///
  /// [runQuery] executes the actual DB query for a given page key.
  /// [requiresSequential] forces pages to be fetched one-by-one (needed
  /// when post-filters shift raw offsets between pages).
  /// [pageSize] is used to detect whether more pages exist.
  /// [isMounted] should return false when the owning controller is disposed.
  /// [onPostFilterOffset] receives the final raw offset after the refresh.
  /// [onLeadingItems] is called with the first page's items so the caller
  /// can track leading task IDs.
  Future<void> refreshLoadedPages({
    required PageQueryFn runQuery,
    required bool requiresSequential,
    required int pageSize,
    required bool Function() isMounted,
    required void Function(int?) onPostFilterOffset,
    required void Function(Iterable<JournalEntity>) onLeadingItems,
  }) async {
    final loadedPageKeys = _loadedVisiblePageKeys();
    final loadedPageCount = loadedPageKeys.length;
    if (loadedPageCount == 0) {
      this
        ..refresh()
        ..fetchNextPage();
      return;
    }

    final refreshToken = Object();
    startRetainedRefresh(refreshToken);

    try {
      late final List<List<JournalEntity>> refreshedPages;
      late final List<int> refreshedKeys;
      int? retainedNextRawOffset;
      if (requiresSequential) {
        refreshedPages = <List<JournalEntity>>[];
        refreshedKeys = <int>[];
        int? nextPageKey = 0;

        for (
          var pageIndex = 0;
          pageIndex < loadedPageCount && nextPageKey != null;
          pageIndex++
        ) {
          final pageKey = nextPageKey;
          refreshedKeys.add(pageKey);

          final items = await runQuery(
            pageKey,
            setPostFilterNextRawOffset: (value) {
              retainedNextRawOffset = value;
            },
          );
          if (!isMounted()) return;
          if (!isRetainedRefresh(refreshToken)) return;

          refreshedPages.add(items);

          if (pageIndex < loadedPageCount - 1) {
            nextPageKey = items.length < pageSize
                ? null
                : retainedNextRawOffset ?? pageKey + items.length;
          }
        }
      } else {
        refreshedKeys = loadedPageKeys;
        refreshedPages = await Future.wait(
          refreshedKeys.map((key) => runQuery(key)),
        );
        if (!isMounted()) return;
        if (!isRetainedRefresh(refreshToken)) return;
      }

      final hasNextPage =
          refreshedPages.length == loadedPageCount &&
          refreshedPages.isNotEmpty &&
          refreshedPages.last.length == pageSize;

      onPostFilterOffset(
        requiresSequential && hasNextPage ? retainedNextRawOffset : null,
      );

      if (refreshedPages.isNotEmpty) {
        onLeadingItems(refreshedPages.first);
      }

      replacePages(
        refreshedPages,
        keys: refreshedKeys,
        hasNextPage: hasNextPage,
      );
    } catch (error, stackTrace) {
      DevLogger.warning(
        name: 'JournalPagingController',
        message: 'Error in retained visible-page refresh: $error\n$stackTrace',
      );
      if (!isMounted()) return;
      if (!isRetainedRefresh(refreshToken)) return;
      finishRetainedRefreshWithError(
        error,
        refreshToken: refreshToken,
      );
      if (error is! Exception) rethrow;
    }
  }

  /// Returns page keys for non-empty loaded pages.
  List<int> _loadedVisiblePageKeys() {
    final pages = value.pages;
    final keys = value.keys;
    if (pages == null || keys == null) return const [];

    final sharedLength = pages.length < keys.length
        ? pages.length
        : keys.length;
    final loadedPageKeys = <int>[];
    for (var index = 0; index < sharedLength; index++) {
      if (pages[index].isNotEmpty) {
        loadedPageKeys.add(keys[index]);
      }
    }
    return loadedPageKeys;
  }
}
