import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';

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
}
